(* ht-lookup — look up records in the HathiTrust Digital Library by identifier.

   Thin client over the HathiTrust Bibliographic API
   (https://catalog.hathitrust.org/api/volumes/). Given one or more
   identifiers it prints each catalog record's metadata and the list of
   digitized items (volumes), including each item's HathiTrust id (htid),
   reading-room URL, and US access status (Full view vs Limited/search-only):

       ht-lookup oclc 424023
       ht-lookup isbn 9780030110405 lccn 62009520
       ht-lookup --json --full recordnumber 000578050

   Identifier types: oclc, lccn, issn, isbn, htid, recordnumber. Up to 20
   identifiers per call (the API's batch limit).

   This API does identifier lookup, not keyword/full-text search: HathiTrust's
   free-text catalog search is not available as an open API (it sits behind a
   bot challenge), and the page-content Data API was retired in July 2024. To
   go from a title to an identifier, search the catalog in a browser at
   https://catalog.hathitrust.org and feed the OCLC/record number back here.

   HTTPS is delegated to the `curl` binary (must be on PATH) so the release
   build can be a fully static musl executable with no TLS stack of its own. *)

let prog = "ht-lookup"
let max_ids = 20

(* The Bibliographic API base. Overridable via HT_API_BASE so the test
   harness can point at a local stub instead of the live service. *)
let api_base =
  match Sys.getenv_opt "HT_API_BASE" with
  | Some v when String.trim v <> "" -> String.trim v
  | _ -> "https://catalog.hathitrust.org/api/volumes"

let die fmt =
  Printf.ksprintf (fun msg -> prerr_endline (prog ^ ": " ^ msg); exit 1) fmt

let valid_id_types = [ "oclc"; "lccn"; "issn"; "isbn"; "htid"; "recordnumber" ]

(* ------------------------------------------------------------- json helpers *)

open Yojson.Safe.Util

(* HathiTrust returns string-valued fields as JSON arrays (e.g. "titles",
   "oclcs"); pull them as an OCaml string list, tolerating absence. *)
let strings_of name json =
  match member name json with
  | `List xs -> List.filter_map (function `String s -> Some s | _ -> None) xs
  | _ -> []

let string_of name json =
  match member name json with `String s -> Some s | _ -> None

(* enumcron is `false` for single-volume works, or a string like "v.2 1881"
   for serials/multi-volume sets. *)
let enumcron_of json =
  match member "enumcron" json with `String s -> Some s | _ -> None

(* ---------------------------------------------------------------- http (curl) *)

let truncated s = if String.length s > 300 then String.sub s 0 300 ^ "..." else s

let fetch url =
  let argv =
    [ "curl"; "-sS"; "-L";
      "-H"; "Accept: application/json";
      "-H"; "User-Agent: ht-lookup";
      "-w"; "\n%{http_code}";
      "--max-time"; "30";
      url ]
  in
  let cmd = String.concat " " (List.map Filename.quote argv) in
  let from_curl = Unix.open_process_in cmd in
  let out = In_channel.input_all from_curl in
  (match Unix.close_process_in from_curl with
   | Unix.WEXITED 0 -> ()
   | Unix.WEXITED n -> die "curl failed (exit %d): %s" n (String.trim out)
   | Unix.WSIGNALED _ | Unix.WSTOPPED _ -> die "curl was killed");
  let body, status =
    match String.rindex_opt out '\n' with
    | None -> die "malformed curl output"
    | Some i ->
        (String.sub out 0 i,
         int_of_string_opt (String.trim (String.sub out (i + 1) (String.length out - i - 1))))
  in
  (match status with
   | Some s when s >= 200 && s < 300 -> ()
   | Some s -> die "HathiTrust API -> HTTP %d: %s" s (truncated body)
   | None -> die "no HTTP status in curl output");
  match Yojson.Safe.from_string body with
  | json -> json
  | exception (Yojson.Json_error m) -> die "invalid JSON from API: %s" m

(* ----------------------------------------------------------------- rendering *)

let line fmt = Printf.ksprintf print_endline fmt

(* records is an object {recordnumber: record}; an empty result is `[]`. *)
let records_assoc json =
  match member "records" json with `Assoc kvs -> kvs | _ -> []

let items_list json =
  match member "items" json with `List xs -> xs | _ -> []

let join = String.concat ", "

let print_result ~query json =
  let records = records_assoc json in
  if records = [] then (line "%s: no record found" query; print_newline ())
  else
    let all_items = items_list json in
    List.iter
      (fun (recnum, rec_) ->
         let title = match strings_of "titles" rec_ with t :: _ -> t | [] -> "(untitled)" in
         let dates = strings_of "publishDates" rec_ in
         line "%s%s" title (match dates with [] -> "" | _ -> " (" ^ join dates ^ ")");
         (match string_of "recordURL" rec_ with Some u -> line "  record:  %s" u | None -> ());
         let show label key =
           match strings_of key rec_ with [] -> () | xs -> line "  %-8s %s" label (join xs)
         in
         show "oclc:" "oclcs";
         show "lccn:" "lccns";
         show "isbn:" "isbns";
         show "issn:" "issns";
         (* MARC-XML is only present with --full; note it rather than dump it. *)
         (match member "marc-xml" rec_ with
          | `String _ -> line "  marc-xml: present (use --json to extract)"
          | _ -> ());
         let items = List.filter (fun it -> string_of "fromRecord" it = Some recnum) all_items in
         line "  items (%d):" (List.length items);
         List.iter
           (fun it ->
              let rights = Option.value (string_of "usRightsString" it) ~default:"?" in
              let htid = Option.value (string_of "htid" it) ~default:"?" in
              let orig = Option.value (string_of "orig" it) ~default:"" in
              let vol = match enumcron_of it with Some v -> "  [" ^ v ^ "]" | None -> "" in
              line "    [%s] %s%s%s" rights htid (if orig = "" then "" else "  " ^ orig) vol;
              match string_of "itemURL" it with Some u -> line "        %s" u | None -> ())
           items)
      records;
    print_newline ()

(* ----------------------------------------------------------------------- main *)

let usage () =
  print_string (Printf.sprintf
    "usage: %s [--full] [--json] <idtype> <id> [<idtype> <id> ...]\n\n\
     Look up HathiTrust catalog records by identifier and list their\n\
     digitized items (htid, reading-room URL, US access status).\n\n\
     idtype is one of: %s\n\n\
     Options:\n\
     \    --full   request full MARC records (MARC-XML; pair with --json)\n\
     \    --json   print the raw API JSON instead of the formatted view\n\
     \    -h, --help\n\n\
     Up to %d identifiers per call. Examples:\n\
     \    %s oclc 424023\n\
     \    %s isbn 9780030110405 lccn 62009520\n\
     \    %s --json --full recordnumber 000578050\n\n\
     Note: this is identifier lookup, not keyword search. Find an identifier\n\
     for a title at https://catalog.hathitrust.org and pass it here.\n"
    prog (join valid_id_types) max_ids prog prog prog)

let () =
  let args = List.tl (Array.to_list Sys.argv) in
  if args = [] || List.mem "-h" args || List.mem "--help" args then (usage (); exit (if args = [] then 1 else 0));
  let full = List.mem "--full" args in
  let json_out = List.mem "--json" args in
  let positional = List.filter (fun a -> a <> "--full" && a <> "--json") args in
  List.iter
    (fun a -> if String.length a > 1 && a.[0] = '-' then die "unknown option %S (try --help)" a)
    positional;

  (* Positional args are <idtype> <id> pairs. *)
  let rec pairs = function
    | [] -> []
    | [ lone ] -> die "identifier value missing after %S" lone
    | idtype :: id :: rest ->
        if not (List.mem idtype valid_id_types) then
          die "unknown idtype %S (expected one of: %s)" idtype (join valid_id_types);
        if String.trim id = "" then die "empty identifier for %S" idtype;
        (idtype, id) :: pairs rest
  in
  let ids = pairs positional in
  if ids = [] then die "no identifiers given (try --help)";
  if List.length ids > max_ids then
    die "too many identifiers (%d); the API allows at most %d per call" (List.length ids) max_ids;

  let query = String.concat ";" (List.map (fun (t, v) -> t ^ ":" ^ v) ids) in
  let kind = if full then "full" else "brief" in
  let url = Printf.sprintf "%s/%s/json/%s" api_base kind query in
  let json = fetch url in

  if json_out then print_endline (Yojson.Safe.pretty_to_string json)
  else
    (* Top level maps each "idtype:id" query back to its {records, items}. *)
    match json with
    | `Assoc kvs -> List.iter (fun (query, result) -> print_result ~query result) kvs
    | _ -> die "unexpected API response shape"
