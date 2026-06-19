(* hathifiles — list and download the HathiTrust HathiFiles metadata dumps.

   The HathiFiles are tab-separated dumps describing every item in the
   HathiTrust Digital Library: a monthly "full" file (~18M rows) plus daily
   "update" deltas, all gzipped. This tool resolves and downloads them; the
   data files carry NO header row, so it also emits the 26-column schema for
   feeding the result to a TSV-aware query tool (dtcat / dtfilter).

       hathifiles list                      # what's available (newest first)
       hathifiles fetch                     # latest monthly full file
       hathifiles fetch --date 20260601     # the full file for that date
       hathifiles fetch --update --date 20260618
       hathifiles header                    # tab-separated column names
       hathifiles header --describe         # column names + descriptions

   Then query, prepending the header so column names resolve:

       cat <(hathifiles header) <(zcat hathi_full_20260601.txt.gz) > hf.tsv
       dtfilter hf.tsv --filter 'rights=pd' --filter 'lang=eng' --columns htid,title

   The HathiFiles host serves the listing and files only to browser-like
   clients, so requests carry a User-Agent and Referer. HTTPS and download
   resume are delegated to `curl` (must be on PATH), which keeps the release
   build a fully static musl executable with no TLS stack of its own. *)

let prog = "hathifiles"

let die fmt =
  Printf.ksprintf (fun msg -> prerr_endline (prog ^ ": " ^ msg); exit 1) fmt

(* Overridable via HATHIFILES_BASE so the test harness can point at a stub. *)
let base_url =
  match Sys.getenv_opt "HATHIFILES_BASE" with
  | Some v when String.trim v <> "" -> String.trim v
  | _ -> "https://www.hathitrust.org/files/hathifiles"

let listing_url = base_url ^ "/hathi_file_list.json"
let referer = "https://www.hathitrust.org/hathifiles"
let user_agent = "Mozilla/5.0 (compatible; hathifiles-cli)"

(* The HathiFiles column schema, in file order. The .gz dumps have no header
   row, so these names must be supplied when querying. See
   https://www.hathitrust.org/hathifiles for authoritative descriptions. *)
let columns =
  [ "htid", "HathiTrust volume id (e.g. mdp.39015...); key for the catalog and reading room";
    "access", "allow / deny — whether full text is viewable in the US";
    "rights", "rights attribute code (pd, ic, und, ...)";
    "ht_bib_key", "HathiTrust catalog record number (the bib API's recordnumber)";
    "description", "enumeration/chronology (volume/issue), if any";
    "source", "contributing institution code";
    "source_bib_num", "local bib record number at the source institution";
    "oclc_num", "OCLC number(s), comma-separated";
    "isbn", "ISBN(s)";
    "issn", "ISSN(s)";
    "lccn", "LCCN(s)";
    "title", "title";
    "imprint", "publisher / place / date statement";
    "rights_reason_code", "why the rights attribute was assigned (bib, ren, ncn, ...)";
    "rights_timestamp", "when the rights determination was recorded";
    "us_gov_doc_flag", "1 if a US federal government document, else 0";
    "rights_date_used", "publication date used in the rights determination";
    "pub_place", "MARC place-of-publication code";
    "lang", "MARC language code (eng, ger, ...)";
    "bib_fmt", "bibliographic format (BK book, SE serial, ...)";
    "collection_code", "HathiTrust collection code";
    "content_provider_code", "institution that provided the content";
    "responsible_entity_code", "institution responsible for the item";
    "digitization_agent_code", "who digitized it (google, ia, ...)";
    "access_profile_code", "access profile (google, open, page, pdus)";
    "author", "author" ]

(* ----------------------------------------------------------------- curl *)

let truncated s = if String.length s > 300 then String.sub s 0 300 ^ "..." else s

(* Fetch a URL's body (used for the small JSON listing). *)
let http_get url =
  let argv =
    [ "curl"; "-sS"; "-L"; "-A"; user_agent; "-H"; "Referer: " ^ referer;
      "-w"; "\n%{http_code}"; "--max-time"; "60"; url ]
  in
  let cmd = String.concat " " (List.map Filename.quote argv) in
  let ic = Unix.open_process_in cmd in
  let out = In_channel.input_all ic in
  (match Unix.close_process_in ic with
   | Unix.WEXITED 0 -> ()
   | Unix.WEXITED n -> die "curl failed (exit %d): %s" n (String.trim out)
   | Unix.WSIGNALED _ | Unix.WSTOPPED _ -> die "curl was killed");
  match String.rindex_opt out '\n' with
  | None -> die "malformed curl output"
  | Some i ->
      let body = String.sub out 0 i in
      (match int_of_string_opt (String.trim (String.sub out (i + 1) (String.length out - i - 1))) with
       | Some s when s >= 200 && s < 300 -> body
       | Some s -> die "%s -> HTTP %d: %s" url s (truncated body)
       | None -> die "no HTTP status in curl output")

(* Download a URL to a file, resuming a partial download (-C -) and following
   redirects, with a progress bar on stderr. *)
let download url ~dest =
  let argv =
    [ "curl"; "-fL"; "-C"; "-"; "--retry"; "3"; "--progress-bar";
      "-A"; user_agent; "-H"; "Referer: " ^ referer; "-o"; dest; url ]
  in
  let pid = Unix.create_process "curl" (Array.of_list argv) Unix.stdin Unix.stderr Unix.stderr in
  match Unix.waitpid [] pid with
  | _, Unix.WEXITED 0 -> ()
  | _, Unix.WEXITED n -> die "curl download failed (exit %d) for %s" n url
  | _, (Unix.WSIGNALED _ | Unix.WSTOPPED _) -> die "curl download was killed"

(* --------------------------------------------------------------- listing *)

open Yojson.Safe.Util

type entry = { filename : string; full : bool; size : int; modified : string }

let parse_listing body =
  match Yojson.Safe.from_string body with
  | `List xs ->
      List.map
        (fun j ->
           { filename = (match member "filename" j with `String s -> s | _ -> die "listing entry missing filename");
             full = (match member "full" j with `Bool b -> b | _ -> false);
             size = (match member "size" j with `Int n -> n | _ -> 0);
             modified = (match member "modified" j with `String s -> s | _ -> "") })
        xs
  | _ -> die "unexpected listing shape (expected a JSON array)"
  | exception Yojson.Json_error m -> die "invalid listing JSON: %s" m

let get_listing () = parse_listing (http_get listing_url)

(* Date is embedded in the filename: hathi_{full,upd}_YYYYMMDD.txt.gz *)
let date_of e =
  try String.sub e.filename (String.rindex e.filename '_' + 1) 8
  with _ -> ""

let latest ~full entries =
  let cands = List.filter (fun e -> e.full = full) entries in
  match List.sort (fun a b -> String.compare (date_of b) (date_of a)) cands with
  | e :: _ -> e
  | [] -> die "no %s files found in listing" (if full then "full" else "update")

let human_size n =
  let f = float_of_int n in
  if f >= 1e9 then Printf.sprintf "%.1f GB" (f /. 1e9)
  else if f >= 1e6 then Printf.sprintf "%.1f MB" (f /. 1e6)
  else if f >= 1e3 then Printf.sprintf "%.1f KB" (f /. 1e3)
  else Printf.sprintf "%d B" n

(* ------------------------------------------------------------------ cmds *)

let cmd_list ~json =
  let body = http_get listing_url in
  if json then print_string body
  else begin
    let entries = parse_listing body in
    let sorted = List.sort (fun a b -> String.compare (date_of b) (date_of a)) entries in
    Printf.printf "%-28s %-7s %10s  %s\n" "filename" "kind" "size" "modified";
    List.iter
      (fun e ->
         Printf.printf "%-28s %-7s %10s  %s\n"
           e.filename (if e.full then "full" else "update") (human_size e.size) e.modified)
      sorted
  end

let cmd_fetch ~want_update ~date ~out =
  let filename =
    match date with
    | Some d -> Printf.sprintf "hathi_%s_%s.txt.gz" (if want_update then "upd" else "full") d
    | None -> (latest ~full:(not want_update) (get_listing ())).filename
  in
  let dest = match out with Some p -> p | None -> filename in
  let url = base_url ^ "/" ^ filename in
  prerr_endline (prog ^ ": downloading " ^ url);
  download url ~dest;
  print_endline dest

let cmd_header ~describe =
  if describe then
    List.iter (fun (name, desc) -> Printf.printf "%-26s %s\n" name desc) columns
  else
    print_endline (String.concat "\t" (List.map fst columns))

(* Convert the decompressed TSV on stdin to NDJSON with the named columns, one
   JSON object per line, every value a string. HathiFiles is tab-separated with
   no quoting and titles contain raw double-quotes, which defeats CSV/TSV
   readers that infer types or honour quotes (e.g. polars/dtcat); emitting
   explicit string fields sidesteps both problems, after which dtfilter/dtcat
   read it cleanly (or convert it to parquet). *)
let cmd_to_ndjson () =
  let names = Array.of_list (List.map fst columns) in
  let ncols = Array.length names in
  let buf = Buffer.create 4096 in
  let emit line =
    let fields = String.split_on_char '\t' line in
    Buffer.clear buf;
    Buffer.add_char buf '{';
    List.iteri
      (fun i v ->
         if i < ncols then begin
           if i > 0 then Buffer.add_char buf ',';
           (* Yojson handles all string escaping (quotes, backslashes, control chars). *)
           Buffer.add_string buf (Yojson.Safe.to_string (`String names.(i)));
           Buffer.add_char buf ':';
           Buffer.add_string buf (Yojson.Safe.to_string (`String v))
         end)
      fields;
    Buffer.add_char buf '}';
    print_string (Buffer.contents buf);
    print_char '\n'
  in
  try while true do emit (input_line stdin) done
  with End_of_file -> ()

(* ------------------------------------------------------------------ main *)

let usage () =
  print_string (Printf.sprintf
    "usage: %s <command> [options]\n\n\
     Commands:\n\
     \  list                 list available HathiFiles (newest first)\n\
     \  fetch                 download a HathiFile (resumable)\n\
     \  header                print the 26-column TSV schema\n\
     \  to-ndjson            convert decompressed TSV on stdin to NDJSON (all-string fields)\n\n\
     list options:\n\
     \  --json               print the raw listing JSON\n\n\
     fetch options:\n\
     \  --full               latest monthly full file (default)\n\
     \  --update             with --date, the daily update file; alone, the latest update\n\
     \  --date YYYYMMDD      the file for a specific date\n\
     \  -o, --out PATH       output path (default: the source filename)\n\n\
     header options:\n\
     \  --describe           print a column-name + description per line\n\n\
     Query a downloaded file. For dtcat/dtfilter, convert to NDJSON first\n\
     (their TSV reader trips on HathiFiles' untyped, unquoted fields):\n\
     \  zcat hathi_full_YYYYMMDD.txt.gz | %s to-ndjson > hf.ndjson\n\
     \  dtfilter hf.ndjson --filter 'rights=pd' --filter 'lang=eng' --columns htid,title\n\
     Or filter the raw TSV directly with awk (column order = %s header):\n\
     \  zcat hathi_full_YYYYMMDD.txt.gz | awk -F'\\t' '$3==\"pd\"&&$19==\"eng\"{print $1\"\\t\"$12}'\n"
    prog prog prog)

let () =
  let args = List.tl (Array.to_list Sys.argv) in
  match args with
  | [] | "-h" :: _ | "--help" :: _ -> usage (); exit (match args with [] -> 1 | _ -> 0)
  | cmd :: rest ->
      let has f = List.mem f rest in
      let opt_value names =
        let rec find = function
          | k :: v :: _ when List.mem k names -> Some v
          | _ :: tl -> find tl
          | [] -> None
        in find rest
      in
      (match cmd with
       | "list" -> cmd_list ~json:(has "--json")
       | "fetch" ->
           let want_update = has "--update" in
           if has "--full" && want_update then die "--full and --update are mutually exclusive";
           let date = opt_value [ "--date" ] in
           (match date with
            | Some d when not (String.length d = 8 && String.for_all (fun c -> c >= '0' && c <= '9') d) ->
                die "--date must be YYYYMMDD, got %S" d
            | _ -> ());
           cmd_fetch ~want_update ~date ~out:(opt_value [ "-o"; "--out" ])
       | "header" -> cmd_header ~describe:(has "--describe")
       | "to-ndjson" -> cmd_to_ndjson ()
       | other -> die "unknown command %S (try --help)" other)
