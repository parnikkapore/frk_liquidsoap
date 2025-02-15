(*****************************************************************************

  Liquidsoap, a programmable audio stream generator.
  Copyright 2003-2022 Savonet team

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details, fully stated in the COPYING
  file at the root of the liquidsoap distribution.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA

 *****************************************************************************)

open Liquidsoap_lang.Lang_core

let log = Log.make ["lang"]
let metadata_t = list_t (product_t string_t string_t)

let to_metadata_list t =
  let pop v =
    let f (a, b) = (to_string a, to_string b) in
    f (to_product v)
  in
  List.map pop (to_list t)

let to_metadata t =
  let t = to_metadata_list t in
  let metas = Hashtbl.create 10 in
  List.iter (fun (a, b) -> Hashtbl.add metas a b) t;
  metas

let metadata m =
  list (Hashtbl.fold (fun k v l -> product (string k) (string v) :: l) m [])

module V = MkAbstract (struct
  type content = Source.source

  let name = "source"
  let descr s = Printf.sprintf "<source#%s>" s#id

  let to_json _ =
    raise
      Runtime_error.(
        Runtime_error
          {
            kind = "json";
            msg = Printf.sprintf "Sources cannot be represented as json";
            pos = [];
          })

  let compare s1 s2 = Stdlib.compare s1#id s2#id
end)

let source_methods =
  [
    ( "id",
      ([], fun_t [] string_t),
      "Identifier of the source.",
      fun s -> val_fun [] (fun _ -> string s#id) );
    ( "is_ready",
      ([], fun_t [] bool_t),
      "Indicate if a source is ready to stream. This does not mean that the \
       source is currently streaming, just that its resources are all properly \
       initialized.",
      fun s -> val_fun [] (fun _ -> bool s#is_ready) );
    ( "last_metadata",
      ([], fun_t [] (nullable_t metadata_t)),
      "Return the last metadata from the source.",
      fun s ->
        val_fun [] (fun _ ->
            match s#last_metadata with None -> null | Some m -> metadata m) );
    ( "on_metadata",
      ([], fun_t [(false, "", fun_t [(false, "", metadata_t)] unit_t)] unit_t),
      "Call a given handler on metadata packets.",
      fun s ->
        val_fun [("", "", None)] (fun p ->
            let f = assoc "" 1 p in
            s#on_metadata (fun m -> ignore (apply f [("", metadata m)]));
            unit) );
    ( "on_get_ready",
      ([], fun_t [(false, "", fun_t [] unit_t)] unit_t),
      "Register a function to be called after the source is asked to get \
       ready. This is when, for instance, the source's final ID is set.",
      fun s ->
        val_fun [("", "", None)] (fun p ->
            let f = assoc "" 1 p in
            s#on_get_ready (fun () -> ignore (apply f []));
            unit) );
    ( "on_shutdown",
      ([], fun_t [(false, "", fun_t [] unit_t)] unit_t),
      "Register a function to be called when source shuts down.",
      fun s ->
        val_fun [("", "", None)] (fun p ->
            let f = assoc "" 1 p in
            s#on_shutdown (fun () -> ignore (apply f []));
            unit) );
    ( "on_leave",
      ([], fun_t [(false, "", fun_t [] unit_t)] unit_t),
      "Register a function to be called when source is not used anymore by \
       another source.",
      fun s ->
        val_fun [("", "", None)] (fun p ->
            let f = assoc "" 1 p in
            s#on_leave (fun () -> ignore (apply f []));
            unit) );
    ( "on_track",
      ([], fun_t [(false, "", fun_t [(false, "", metadata_t)] unit_t)] unit_t),
      "Call a given handler on new tracks.",
      fun s ->
        val_fun [("", "", None)] (fun p ->
            let f = assoc "" 1 p in
            s#on_track (fun m -> ignore (apply f [("", metadata m)]));
            unit) );
    ( "remaining",
      ([], fun_t [] float_t),
      "Estimation of remaining time in the current track.",
      fun s ->
        val_fun [] (fun _ ->
            float
              (let r = s#remaining in
               if r < 0 then infinity else Frame.seconds_of_main r)) );
    ( "elapsed",
      ([], fun_t [] float_t),
      "Elapsed time in the current track.",
      fun s ->
        val_fun [] (fun _ ->
            float
              (let e = s#elapsed in
               if e < 0 then infinity else Frame.seconds_of_main e)) );
    ( "duration",
      ([], fun_t [] float_t),
      "Estimation of the duration of the current track.",
      fun s ->
        val_fun [] (fun _ ->
            float
              (let d = s#duration in
               if d < 0 then infinity else Frame.seconds_of_main d)) );
    ( "self_sync",
      ([], fun_t [] bool_t),
      "Is the source currently controling its own real-time loop.",
      fun s -> val_fun [] (fun _ -> bool (snd s#self_sync)) );
    ( "log",
      ( [],
        record_t
          [
            ( "level",
              method_t
                (fun_t [] (nullable_t int_t))
                [
                  ( "set",
                    ([], fun_t [(false, "", int_t)] unit_t),
                    "Set the source's log level" );
                ] );
          ] ),
      "Get or set the source's log level, from `1` to `5`.",
      fun s ->
        record
          [
            ( "level",
              meth
                (val_fun [] (fun _ ->
                     match s#log#level with Some lvl -> int lvl | None -> null))
                [
                  ( "set",
                    val_fun [("", "", None)] (fun p ->
                        let lvl = min 5 (max 1 (to_int (List.assoc "" p))) in
                        s#log#set_level lvl;
                        unit) );
                ] );
          ] );
    ( "is_up",
      ([], fun_t [] bool_t),
      "Indicate that the source can be asked to produce some data at any time. \
       This is `true` when the source is currently being used or if it could \
       be used at any time, typically inside a `switch` or `fallback`.",
      fun s -> val_fun [] (fun _ -> bool s#is_up) );
    ( "is_active",
      ([], fun_t [] bool_t),
      "`true` if the source is active, i.e. it is continuously animated by its \
       own clock whenever it is ready. Typically, `true` for outputs and \
       sources such as `input.http`.",
      fun s -> val_fun [] (fun _ -> bool s#is_active) );
    ( "seek",
      ([], fun_t [(false, "", float_t)] float_t),
      "Seek forward, in seconds (returns the amount of time effectively \
       seeked).",
      fun s ->
        val_fun [("", "", None)] (fun p ->
            float
              (Frame.seconds_of_main
                 (s#seek (Frame.main_of_seconds (to_float (List.assoc "" p))))))
    );
    ( "skip",
      ([], fun_t [] unit_t),
      "Skip to the next track.",
      fun s ->
        val_fun [] (fun _ ->
            s#abort_track;
            unit) );
    ( "fallible",
      ([], bool_t),
      "Indicate if a source may fail, i.e. may not be ready to stream.",
      fun s -> bool (s#stype = `Fallible) );
    ( "time",
      ([], fun_t [] float_t),
      "Get a source's time, based on its assigned clock.",
      fun s ->
        val_fun [] (fun _ ->
            let ticks =
              if Source.Clock_variables.is_known s#clock then
                (Source.Clock_variables.get s#clock)#get_tick
              else 0
            in
            let frame_position =
              Lazy.force Frame.duration *. float_of_int ticks
            in
            let in_frame_position =
              Frame.seconds_of_main (Frame.position s#memo)
            in
            float (frame_position +. in_frame_position)) );
  ]

let source_t ?(methods = false) frame_t =
  let t =
    Type.make
      (Type.Constr
         { Type.constructor = "source"; params = [(Type.Invariant, frame_t)] })
  in
  if methods then
    method_t t
      (List.map (fun (name, t, doc, _) -> (name, t, doc)) source_methods)
  else t

let source s =
  meth (V.to_value s)
    (List.map (fun (name, _, _, fn) -> (name, fn s)) source_methods)

let to_source = V.of_value
let to_source_list l = List.map to_source (to_list l)

(** A method: name, type scheme, documentation and implementation (which takes
    the currently defined source as argument). *)
type 'a operator_method = string * scheme * string * ('a -> value)

(** An operator is a builtin function that builds a source.
  * It is registered using the wrapper [add_operator].
  * Creating the associated function type (and function) requires some work:
  *  - Specify which content_kind the source will carry:
  *    a given fixed number of channels, any fixed, a variable number?
  *  - The content_kind can also be linked to a type variable,
  *    e.g. the parameter of a format type.
  * From this high-level description a type is created. Often it will
  * carry a type constraint.
  * Once the type has been inferred, the function might be executed,
  * and at this point the type might still not be known completely
  * so we have to force its value within the acceptable range. *)
let add_operator =
  let _meth = meth in
  fun ~(category : Documentation.source) ~descr ?(flags = [])
      ?(meth = ([] : 'a operator_method list)) name proto ~return_t f ->
    let compare (x, _, _, _) (y, _, _, _) =
      match (x, y) with
        | "", "" -> 0
        | _, "" -> -1
        | "", _ -> 1
        | x, y -> Stdlib.compare x y
    in
    let proto =
      ( "id",
        nullable_t string_t,
        Some null,
        Some "Force the value of the source ID." )
      :: List.stable_sort compare proto
    in
    let f env =
      let src : < Source.source ; .. > = f env in
      ignore
        (Option.map
           (fun id -> src#set_id id)
           (to_valued_option to_string (List.assoc "id" env)));
      let v = source (src :> Source.source) in
      let generalized, return_t = Typing.generalize ~level:0 return_t in
      let return_t = Typing.instantiate ~level:0 ~generalized return_t in
      Typing.((V.of_value v)#frame_type <: return_t);
      _meth v (List.map (fun (name, _, _, fn) -> (name, fn src)) meth)
    in
    let f env =
      let pos = None in
      try
        let ret = f env in
        if category = `Output then (
          let m, _ = Value.split_meths ret in
          _meth unit m)
        else ret
      with
        | Source.Clock_conflict (a, b) ->
            raise (Error.Clock_conflict (pos, a, b))
        | Source.Clock_loop (a, b) -> raise (Error.Clock_loop (pos, a, b))
    in
    let return_t = source_t ~methods:true return_t in
    let return_t =
      method_t return_t
        (List.map (fun (name, typ, doc, _) -> (name, typ, doc)) meth)
    in
    let return_t =
      if category = `Output then (
        let m, _ = Type.split_meths return_t in
        let m =
          List.map (fun Type.{ meth = x; scheme = y; doc = z } -> (x, y, z)) m
        in
        method_t unit_t m)
      else return_t
    in
    let category = `Source category in
    add_builtin ~category ~descr ~flags name proto return_t f

let iter_sources ?on_reference ~static_analysis_failed f v =
  let itered_values = ref [] in
  let rec iter_term env v =
    match v.Term.term with
      | Term.Ground _ | Term.Encoder _ -> ()
      | Term.List l -> List.iter (iter_term env) l
      | Term.Tuple l -> List.iter (iter_term env) l
      | Term.Null -> ()
      | Term.Cast (a, _) -> iter_term env a
      | Term.Meth (_, a, b) ->
          iter_term env a;
          iter_term env b
      | Term.Invoke (a, _) -> iter_term env a
      | Term.Open (a, b) ->
          iter_term env a;
          iter_term env b
      | Term.Let { Term.def = a; body = b; _ } | Term.Seq (a, b) ->
          iter_term env a;
          iter_term env b
      | Term.Var v -> (
          try
            (* If it's locally bound it won't be in [env]. *)
            (* TODO since inner-bound variables don't mask outer ones in [env],
             *   we are actually checking values that may be out of reach. *)
            let v = List.assoc v env in
            if Lazy.is_val v then (
              let v = Lazy.force v in
              iter_value v)
            else ()
          with Not_found -> ())
      | Term.App (a, l) ->
          iter_term env a;
          List.iter (fun (_, v) -> iter_term env v) l
      | Term.Fun (_, proto, body) | Term.RFun (_, _, proto, body) ->
          iter_term env body;
          List.iter
            (fun (_, _, _, v) ->
              match v with Some v -> iter_term env v | None -> ())
            proto
  and iter_value v =
    if not (List.memq v !itered_values) then (
      (* We need to avoid checking the same value multiple times, otherwise we
         get an exponential blowup, see #1247. *)
      itered_values := v :: !itered_values;
      match v.value with
        | _ when V.is_value v -> f (V.of_value v)
        | Ground _ -> ()
        | List l -> List.iter iter_value l
        | Tuple l -> List.iter iter_value l
        | Null -> ()
        | Meth (_, a, b) ->
            iter_value a;
            iter_value b
        | Fun (proto, env, body) ->
            (* The following is necessarily imprecise: we might see sources that
               will be unused in the execution of the function. *)
            iter_term env body;
            List.iter (function _, _, Some v -> iter_value v | _ -> ()) proto
        | FFI (proto, _) ->
            List.iter (function _, _, Some v -> iter_value v | _ -> ()) proto
        | Ref r ->
            if List.memq r !static_analysis_failed then ()
            else (
              (* Do not walk inside references, otherwise the list of "contained"
                 sources may change from one time to the next, which makes it
                 impossible to avoid ill-balanced activations. Not walking inside
                 references does not break things more than they are already:
                 detecting sharing in presence of references to sources cannot be
                 done statically anyway. We display a fat log message to warn
                 about this risky situation. *)
              let may_have_source =
                let rec aux v =
                  match v.value with
                    | _ when V.is_value v -> true
                    | Ground _ | Null -> false
                    | List l -> List.exists aux l
                    | Tuple l -> List.exists aux l
                    | Ref r -> aux (Atomic.get r)
                    | Fun _ | FFI _ -> true
                    | Meth (_, v, t) -> aux v || aux t
                in
                aux v
              in
              static_analysis_failed := r :: !static_analysis_failed;
              if may_have_source then (
                match on_reference with
                  | Some f -> f ()
                  | None ->
                      log#severe
                        "WARNING! Found a reference, potentially containing \
                         sources, inside a dynamic source-producing function. \
                         Static analysis cannot be performed: make sure you \
                         are not sharing sources contained in references!")))
  in
  iter_value v

let iter_sources = iter_sources ~static_analysis_failed:(ref [])
