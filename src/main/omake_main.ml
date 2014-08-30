
include  Omake_pos.MakePos (struct let name = "Omake_main" end);;


let debug_hash = ref false

let print_hash_stats () =
  if !debug_hash then
    Lm_printf.eprintf "@[<v 3>Hash statistics:@ %t@]@." Lm_hash.pp_print_hash_stats

(* List of targets to build. *)
let targets = ref []

let add_target s =
  targets := s :: !targets


let server_flag = ref None

let shell_flag = ref false
let command_string = ref None
let install_flag = ref false
let install_subdirs = ref false
let install_force = ref false

(*
 * Add an random argument.
 *)
let add_unknown options s =
  let () =
    try
      let i = String.index s '=' in
      let l = String.length s in
      let v = String.sub s 0 i in
      let x = String.sub s (succ i) (l - i - 1) in
      Omake_builtin.add_command_def v x
    with
      Not_found -> add_target s in
  options, !shell_flag

(*
 * Arguments.
 *)
let header = "OMake generic system builder, version " ^ Omake_magic.version

let spec =
  Lm_arg.StrictOptions, (**)
  Omake_options.(
  ["Make flags", (**)
   options_spec;
   "Output flags", (**)
   output_spec;
   "Cache management", (**)
   ["--save-interval", Lm_arg.Float (fun f -> Omake_build.save_interval := f), (**)
    (Lm_printf.sprintf "Save the build DB (\".omakedb\") every x seconds (0 disables, default: %F)" (**)
       Omake_magic.default_save_interval);
    "--force-dotomake", Lm_arg.Set Omake_state.always_use_dotomake, (**)
    "Always use $HOME/.omake for .omc cache files";
    "--dotomake", Lm_arg.String (fun s -> Omake_state.set_omake_dir s), (**)
    "Use the specified directory in place of $HOME/.omake"];
   "Helper flags", (**)
   ["--install", Lm_arg.Set install_flag, (**)
    "Install an OMake project into the current directory";
    "--install-all", Lm_arg.SetFold (fun opts b ->
      install_flag := b;
      install_subdirs := b;
      opts), (**)
    "Install an OMake project into the current directory and all subdirectories";
    "--install-force", Lm_arg.SetFold (fun opts b ->
      install_flag := b;
      install_force := b;
      opts), (**)
    "Force overwriting of files during installation; implies --install";
    "--version", Lm_arg.Unit (fun () ->
      Lm_printf.printf "%s\n\nDefault library directory : %s@." Omake_magic.version_message Omake_magic.lib_dir;
      if Omake_state.lib_dir_reason <> "" then
        Lm_printf.printf "Using library directory   : %s\n\t(as specified by the %s)@." (**)
          Omake_state.lib_dir Omake_state.lib_dir_reason;
      exit 0), (**)
    "Print the version string and exit"];
   "Shell flags", (**)
   ["--shell", Lm_arg.Set shell_flag, (**)
    "Run the OMake shell: osh";
    "-i", Lm_arg.SetFold (fun opts b -> Omake_readline.set_interactive b; opts), (**)
    "Treat the session as interactive";
    "-c", Lm_arg.String (fun s -> command_string := Some s), (**)
    "Evaluate the commands from the string"];
   "Debugging flags", (**)
   ["-print-ast",      Lm_arg.Set Omake_eval.print_ast, (**)
    "Print the AST after parsing";
    "-print-ir",       Lm_arg.Set Omake_eval.print_ir, (**)
    "Print the IR";
    "-print-loc",       Lm_arg.Set Omake_ast_print.print_location, (**)
    "Also print locations";
    "-print-rules",    Lm_arg.Set Omake_eval.print_rules, (**)
    "Print the rules after evaluation";
    "-print-files",    Lm_arg.Set Omake_eval.print_files, (**)
    "Print the files as they are read";
    "-debug-deps",     Lm_arg.Set Omake_build.debug_deps, (**)
    "Display dependency information as scanned";
    "-debug-ast-lex",  Lm_arg.Set Omake_ast_lex.debug_lex, (**)
    "Print tokens as they are scanned";
    "-debug-cache",    Lm_arg.Set Omake_cache.debug_cache, (**)
    "Display cache debugging information";
    "-debug-exec",     Lm_arg.Set Omake_exec_util.debug_exec, (**)
    "Display execution debugging information";
    "-debug-rule",     Lm_arg.Set Omake_build.debug_rule, (**)
    "Display debugging information about rule execution";
    "-debug-build",    Lm_arg.Set Omake_build.debug_build, (**)
    "Display debugging information during the build";
    "-debug-scanner",  Lm_arg.Set Omake_env.debug_scanner, (**)
    "Display debugging information for scanner selection";
    "-debug-implicit", Lm_arg.Set Omake_env.debug_implicit, (**)
    "Display debugging information for implicit rule selection";
    "-debug-pos", Lm_arg.Set Lm_position.debug_pos, (**)
    "Print source position information on error";
    "-trace-pos", Lm_arg.Set Lm_position.trace_pos, (**)
    "Trace the program execution";
    "-debug-remote", Lm_arg.Set Omake_exec_remote.debug_remote, (**)
    "Debug remote execution";
    "-debug-active-rules", Lm_arg.Set Omake_rule.debug_active_rules, (**)
    "Debug active rules";
    "-debug-shell", Lm_arg.Set Omake_shell_type.debug_shell, (**)
    "Debug shell operations";
    "-debug-eval", Lm_arg.Set Omake_eval.debug_eval, (**)
    "Debug the evaluator";
    "-debug-lex", Lm_arg.Set Lm_lexer.debug_lex, (**)
    "Debug the lexer";
    "-debug-lexgen", Lm_arg.Set Lm_lexer.debug_lexgen, (**)
    "Debug the lexer generator";
    "-debug-parse", Lm_arg.Set Lm_parser.debug_parse, (**)
    "Debug the parser";
    "-debug-parsegen", Lm_arg.Set Lm_parser.debug_parsegen, (**)
    "Debug the parser generator";
    "-debug-parsing", Lm_arg.Set Omake_builtin_io_fun.debug_parsing, (**)
    "Debug OMake parsing operations";
    "-debug-notify", Lm_arg.Set Lm_notify.debug_notify, (**)
    "Debug the FAM (-p filesystem watch) operations";
    "-debug-db", Lm_arg.Set Omake_env.debug_db, (**)
    "Debug the file database";
    "-debug-hash", Lm_arg.Set debug_hash, (**)
    "Show Lm_hash statistics";
    "-debug-thread", Lm_arg.Set Lm_thread_pool.debug_thread, (**)
    "Show thread operations";
    "-allow-exceptions", Lm_arg.SetFold set_allow_exceptions_opt, (**)
    "Do not catch top-level exceptions (for use with OCAMLRUNPARAM=b)"];
   "Internal flags", (**)
   ["-server", Lm_arg.String (fun s -> server_flag := Some s), (**)
    "Run as a remote server";]])

let concat =
  let buf = Buffer.create 17 in
  let concat sl =
    if sl = [] then
      Filename.dir_sep
    else
      let _ =
        List.iter (fun s ->
          Buffer.add_string buf Filename.dir_sep;
          Buffer.add_string buf s) sl
      in
      let s = Buffer.contents buf in
      Buffer.clear buf;
      s
  in
  concat

(*
 * Find the outermost OMakeroot.
 *)
let chroot () =
  let cwd =
    try
      Unix.getcwd ()
    with
      Unix.Unix_error _ ->
        Lm_printf.eprintf "*** omake: fatal error: current directory does not exist@.";
        exit 1  in
  let len = String.length cwd in
  let start = Lm_filename_util.drive_skip cwd in
  let rec search i =
    if i < start then
      raise (Omake_value_type.OmakeFatal ("can not find " ^ Omake_state.makeroot_name ^ " or " ^ Omake_state.makeroot_short_name))
    else if cwd.[i] = '/' || cwd.[i] = '\\' then
      (* Maybe file is in this directory *)
      let dir = String.sub cwd 0 i in
      if Sys.file_exists (Filename.concat dir Omake_state.makeroot_name)
    || Sys.file_exists (Filename.concat dir Omake_state.makeroot_short_name)
      then
        let rest = String.sub cwd (succ i) (len - i - 1) in
        dir, rest
      else
        search (i - 1)
    else
      search (i - 1)
  in
  let dir, rest =
    if Sys.file_exists (Filename.concat cwd Omake_state.makeroot_name) || Sys.file_exists
      (Filename.concat cwd Omake_state.makeroot_short_name) then
      cwd, "."
    else
      search (len - 1)
  in
  if rest <> "." then
    Lm_printf.eprintf "*** omake: changing directory to %s@." dir;
  Unix.chdir dir;
  Omake_node.Dir.reset_cwd ();
  rest

(*
 * Main program.
 *)
let main options =
  let () = Sys.catch_break true in
  let () =
    if Sys.os_type <> "Win32" then
      Sys.set_signal Sys.sigpipe Sys.Signal_ignore in
  let path = chroot () in
  Omake_build.build options 
    (if Omake_options.opt_cd_root options then
        "."
      else
        path)
    (match !targets with
    | [] -> [".DEFAULT"]
    | l -> List.rev l)(* targets *);
  print_hash_stats ()

(*
 * Main for remote execution.
 *)
let main_remote cwd options =
  (* Set up the environment *)
  Unix.chdir cwd;
  Omake_node.Dir.reset_cwd ();
  let cwd   = Omake_node.Dir.cwd () in
  let exec  = Omake_exec.Exec.create cwd options in
  let cache = Omake_cache.create () in
  let venv  = Omake_env.create options "." exec cache in
  let venv  = Omake_builtin.venv_add_command_defs venv in
  let venv  = Omake_env.venv_add_var venv Omake_var.targets_var (ValString (String.concat " " !targets)) in
  let venv  = Omake_builtin.venv_add_builtins venv in

  (* Shell evaluator *)
  let pos = string_exp_pos "main_remote" in
  let shell = Omake_rule.eval_shell venv pos in
  Omake_exec_remote.main shell options

let _ =
  (* If the executable is named osh, set the shell flag *)
  let () =
    let exe = Lm_filename_util.root (Filename.basename (Sys.argv.(0))) in
    if exe = "osh" then
      shell_flag := true
  in

  (* Parse all the options *)
  let options = Omake_options.default_options in
  let options =
    try
      let s = Sys.getenv "OMAKEFLAGS" in
      let argv = Array.of_list (Sys.argv.(0) :: Lm_string_util.tokens_std s) in
      Lm_arg.fold_argv argv spec options add_unknown header
    with
      Not_found
    | Lm_arg.UsageError ->
      options
  in
  let options =
    try Lm_arg.fold spec options add_unknown header with
      Lm_arg.UsageError ->
      exit 0
    | Lm_arg.BogusArg (s) ->
      Lm_arg.usage spec header;
      Lm_printf.eprintf "@\n@[<hv 3>*** omake fatal error:@ %s@]@." s;
      exit 3
  in
  Lm_thread_core.debug_mutex := !Lm_thread_pool.debug_thread;
  Lm_thread.debug_lock := !Lm_thread_pool.debug_thread;
  (* Run it *)
  match !server_flag with
  | Some cwd -> main_remote cwd options
  | None ->
    if !shell_flag then
      Omake_shell.shell options !command_string (List.rev !targets)
    else if !install_flag then
      if !install_subdirs then
        Omake_install.install_subdirs !install_force
      else
        Omake_install.install_current !install_force
    else if Omake_options.opt_allow_exceptions options then
      main options
    else
      Omake_exn_print.catch main options

