type mode = [ `Default | `Standalone | `Posix ]

let mode = `Default
let get_site name = match name with [] -> "" | s :: _ -> s

(* This is a hack. *)
let prefix () = Filename.(dirname (get_site Liquidsoap_sites.Sites.lib_root))

let rundir () =
  List.fold_left Filename.concat (prefix ()) ["var"; "liquidsoap"; "run"]

let rundir_descr = "(set by dune-site)"

let logdir () =
  List.fold_left Filename.concat (prefix ()) ["var"; "liquidsoap"; "log"]

let logdir_descr = "(set by dune-site)"
let liq_libs_dir () = get_site Liquidsoap_sites.Sites.libs
let liq_libs_dir_descr = "(set by dune-site)"
let bin_dir () = get_site Liquidsoap_sites.Sites.bin
let bin_dir_descr = "(set by dune-site)"
let camomile_dir = CamomileDefaultConfig__.InstallConfig.share_dir
let camomile_dir_descr = "(opam default)"
