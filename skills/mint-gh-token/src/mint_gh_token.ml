(* mint-gh-token — mint a short-lived GitHub App installation access token.

   Signs an RS256 app JWT with the App's PEM private key, exchanges it for an
   installation access token (1 hour life), and prints the bare token on
   stdout for shell capture:

       export GH_TOKEN=$(mint-gh-token)

   Diagnostics go to stderr only. The token is cached on disk and reused
   until < 5 minutes of life remain; a failed cache write warns but never
   loses the freshly minted token.

   Environment:
     GH_APP_KEY       PEM private key content (or use GH_APP_KEY_FILE)
     GH_APP_KEY_FILE  path to the .pem file (used when GH_APP_KEY is unset)
     GH_APP_ID        numeric App ID or the App's Client ID
     GH_APP_OWNER     owner of a repo the App is installed on
     GH_APP_REPO      name of that repo (installation lookup target)
     GH_TOKEN_CACHE   cache file path (default: $TMPDIR/mint_gh_token.cache.json)
     GH_API_URL       API base URL (default: https://api.github.com)

   HTTPS is delegated to the `curl` binary (must be on PATH); the secret
   bearer header is passed on curl's stdin, never on its command line. *)

let refresh_margin_s = 5. *. 60.

(* [exit] has type [int -> 'a], so [die] can be used in any context, like
   [failwith]. [Printf.ksprintf] makes it accept a format string:
   [die "HTTP %d" 404]. *)
let die fmt =
  Printf.ksprintf (fun msg -> prerr_endline ("mint-gh-token: " ^ msg); exit 1) fmt

let note fmt =
  Printf.ksprintf (fun msg -> prerr_endline ("mint-gh-token: " ^ msg)) fmt

(* ------------------------------------------------------------------ env *)

(* [Sys.getenv_opt : string -> string option] — no exceptions, just [None].
   The [when] clause is a pattern guard. *)
let getenv_trimmed name =
  match Sys.getenv_opt name with
  | Some v when String.trim v <> "" -> Some (String.trim v)
  | _ -> None

let require_env name =
  match getenv_trimmed name with
  | Some v -> v
  | None -> die "%s not set" name

(* ---------------------------------------------------------------- cache *)

let cache_path () =
  match getenv_trimmed "GH_TOKEN_CACHE" with
  | Some p -> p
  | None ->
      let tmp = Option.value (getenv_trimmed "TMPDIR") ~default:"/tmp" in
      Filename.concat tmp "mint_gh_token.cache.json"

(* [In_channel.with_open_bin] opens the file, runs the function, and closes
   the channel even if the function raises. *)
let read_file path = In_channel.with_open_bin path In_channel.input_all

(* Seconds from now until an RFC 3339 timestamp like 2026-06-11T17:04:00Z.
   [Ptime.of_rfc3339] returns a [result]; we only care about the success
   case, so the triple's other components are wildcarded. *)
let seconds_until rfc3339 =
  match Ptime.of_rfc3339 rfc3339 with
  | Ok (t, _tz, _consumed) -> Some (Ptime.to_float_s t -. Unix.gettimeofday ())
  | Error _ -> None

(* Returns [Some token] only if the cache file exists, parses, and has more
   than the refresh margin left. Any failure mode just means "no cache". *)
let cached_token path =
  match Yojson.Safe.from_string (read_file path) with
  | exception _ -> None  (* missing file, unreadable, or invalid JSON *)
  | json -> (
      let open Yojson.Safe.Util in
      match
        (member "token" json |> to_string_option,
         member "expires_at" json |> to_string_option)
      with
      | Some token, Some expires -> (
          match seconds_until expires with
          | Some remaining when remaining > refresh_margin_s ->
              note "cached token reused (%.0f min left)" (remaining /. 60.);
              Some token
          | _ -> None)
      | _ -> None)

(* Best effort: returns [false] on failure instead of raising, because by
   the time we write the cache the token is already minted — losing it to a
   read-only /tmp would be worse than not caching (this exact bug existed in
   an earlier Python version of this tool). *)
let write_cache path ~token ~expires_at =
  let json = `Assoc [ ("token", `String token); ("expires_at", `String expires_at) ] in
  match
    Out_channel.with_open_gen
      [ Open_wronly; Open_creat; Open_trunc ] 0o600 path
      (fun oc -> Out_channel.output_string oc (Yojson.Safe.to_string json))
  with
  | () -> true
  | exception Sys_error _ -> false

(* ------------------------------------------------------------------ jwt *)

(* JWTs use base64url without padding (RFC 7515). *)
let b64url s = Base64.encode_string ~pad:false ~alphabet:Base64.uri_safe_alphabet s

let sign_jwt ~app_id key =
  let now = int_of_float (Unix.time ()) in
  (* 60 s clock-skew backdate per GitHub docs; 9 min expiry (max is 10). *)
  let claims =
    `Assoc [ ("iat", `Int (now - 60)); ("exp", `Int (now + 540)); ("iss", `String app_id) ]
    |> Yojson.Safe.to_string
  in
  let signing_input = b64url {|{"alg":"RS256","typ":"JWT"}|} ^ "." ^ b64url claims in
  match X509.Private_key.sign `SHA256 ~scheme:`RSA_PKCS1 key (`Message signing_input) with
  | Ok signature -> signing_input ^ "." ^ b64url signature
  | Error (`Msg m) -> die "signing app JWT: %s" m

(* ----------------------------------------------------------- github api *)

let truncated s = if String.length s > 300 then String.sub s 0 300 ^ "..." else s

(* One GitHub API call via a curl subprocess. [-w "\n%{http_code}"] makes
   curl append the status code as a final line, so we get body + status from
   a single stdout read. [-H @-] tells curl to read extra headers from
   stdin — that is how the bearer token travels without appearing in `ps`. *)
let gh_api ~meth ~bearer url =
  let argv =
    [ "curl"; "-sS"; "-X"; meth;
      "-H"; "@-";
      "-H"; "Accept: application/vnd.github+json";
      "-H"; "X-GitHub-Api-Version: 2022-11-28";
      "-H"; "User-Agent: mint-gh-token";
      "-w"; "\n%{http_code}";
      "--max-time"; "30";
      url ]
  in
  let cmd = String.concat " " (List.map Filename.quote argv) in
  let from_curl, to_curl = Unix.open_process cmd in
  output_string to_curl ("Authorization: Bearer " ^ bearer ^ "\n");
  close_out to_curl;
  let out = In_channel.input_all from_curl in
  (match Unix.close_process (from_curl, to_curl) with
   | Unix.WEXITED 0 -> ()
   | Unix.WEXITED n -> die "curl %s %s failed (exit %d): %s" meth url n (String.trim out)
   | Unix.WSIGNALED _ | Unix.WSTOPPED _ -> die "curl %s %s was killed" meth url);
  let body, status =
    match String.rindex_opt out '\n' with
    | None -> die "curl %s %s: malformed output" meth url
    | Some i ->
        let status_line = String.sub out (i + 1) (String.length out - i - 1) in
        (String.sub out 0 i, int_of_string_opt (String.trim status_line))
  in
  (match status with
   | Some s when s >= 200 && s < 300 -> ()
   | Some s -> die "%s %s -> HTTP %d: %s" meth url s (truncated body)
   | None -> die "curl %s %s: no status code in output" meth url);
  Yojson.Safe.from_string body

(* Extract a field from a response, with a readable error instead of
   yojson's raw [Type_error] exception. *)
let field name conv json =
  try conv (Yojson.Safe.Util.member name json)
  with Yojson.Safe.Util.Type_error _ ->
    die "GitHub response missing %S field: %s" name (truncated (Yojson.Safe.to_string json))

(* ----------------------------------------------------------------- main *)

let usage () =
  prerr_endline
    "usage: mint-gh-token [--no-cache]\n\n\
     Mint a GitHub App installation access token and print it on stdout.\n\
     Requires GH_APP_KEY (or GH_APP_KEY_FILE), GH_APP_ID, GH_APP_OWNER, GH_APP_REPO.\n\
     Cache: $GH_TOKEN_CACHE, default $TMPDIR/mint_gh_token.cache.json."

let () =
  (* mirage-crypto's RSA signing uses blinding, which needs a seeded RNG. *)
  Mirage_crypto_rng_unix.use_default ();
  let args = List.tl (Array.to_list Sys.argv) in
  if List.mem "--help" args || List.mem "-h" args then (usage (); exit 0);
  List.iter (fun a -> if a <> "--no-cache" then die "unknown argument %S (try --help)" a) args;
  let no_cache = List.mem "--no-cache" args in

  let cache = cache_path () in
  (if not no_cache then
     match cached_token cache with
     | Some token -> print_endline token; exit 0
     | None -> ());

  let pem =
    match getenv_trimmed "GH_APP_KEY" with
    | Some key -> key
    | None -> (
        match getenv_trimmed "GH_APP_KEY_FILE" with
        | Some file -> (
            try read_file file
            with Sys_error e -> die "reading GH_APP_KEY_FILE: %s" e)
        | None -> die "GH_APP_KEY (PEM content) or GH_APP_KEY_FILE not set")
  in
  let app_id = require_env "GH_APP_ID" in
  let owner = require_env "GH_APP_OWNER" in
  let repo = require_env "GH_APP_REPO" in
  let api = Option.value (getenv_trimmed "GH_API_URL") ~default:"https://api.github.com" in

  let key =
    match X509.Private_key.decode_pem pem with
    | Ok key -> key
    | Error (`Msg m) -> die "parsing private key: %s" m
  in
  let jwt = sign_jwt ~app_id key in

  let installation =
    gh_api ~meth:"GET" ~bearer:jwt
      (Printf.sprintf "%s/repos/%s/%s/installation" api owner repo)
  in
  let installation_id = field "id" Yojson.Safe.Util.to_int installation in

  let grant =
    gh_api ~meth:"POST" ~bearer:jwt
      (Printf.sprintf "%s/app/installations/%d/access_tokens" api installation_id)
  in
  let token = field "token" Yojson.Safe.Util.to_string grant in
  let expires_at = field "expires_at" Yojson.Safe.Util.to_string grant in

  if not (write_cache cache ~token ~expires_at) then
    note "warning: cache write to %s failed — token still printed; set GH_TOKEN_CACHE to a writable path" cache;
  note "new token for %s/%s, expires %s" owner repo expires_at;
  print_endline token
