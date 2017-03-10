(*****************************************************************************

  Liquidsoap, a programmable audio stream generator.
  Copyright 2003-2017 Savonet team

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
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

 *****************************************************************************)

exception Invalid_override of string

let (--) = Int64.sub
let (++) = Int64.add

let ticks_of_offset offset =
  Int64.of_float (offset *. float (Lazy.force Frame.master_rate))

class on_offset ~kind ~force ~offset ~override f s =
object(self)
  inherit Source.operator ~name:"on_offset" kind [s]

  method stype = s#stype
  method is_ready = s#is_ready
  method remaining = s#remaining
  method abort_track = s#abort_track
  method seek n = s#seek n

  val mutable latest_metadata = Hashtbl.create 0
  val mutable elapsed = 0L
  val mutable offset = ticks_of_offset offset
  val mutable executed = false

  method private execute =
    self#log#f 4 "Executing on_offset callback.";
    ignore(Lang.apply ~t:Lang.unit_t f ["",Lang.metadata latest_metadata]);
    executed <- true

  method private get_frame ab =
    let pos =
      Int64.of_int (Frame.position ab)
    in
    s#get ab ;
    let new_pos =
      Int64.of_int (Frame.position ab)
    in
    elapsed <- elapsed ++ new_pos -- pos;
    let compare x y = - (compare x y) in
    let l = List.sort compare (Frame.get_all_metadata ab) in
    begin
      try
        latest_metadata <- snd (List.hd l);
        let pos = Hashtbl.find latest_metadata override in
        let pos =
          try float_of_string pos
          with Failure _ -> raise (Invalid_override pos)
        in
        let ticks = ticks_of_offset pos in
        self#log#f 4 "Setting new offset to %.02fs (%Li ticks)" pos ticks;
        offset <- ticks
      with
        | Failure _
        | Not_found -> ()
        | Invalid_override pos ->
            self#log#f 3 "Invalid value for override metadata: %s" pos
    end;
    if not executed && offset <= elapsed then
      self#execute;
    if Frame.is_partial ab then
     begin
      if force && not executed then
        self#execute;
      executed <- false;
      elapsed <- 0L
     end
end

let () =
  let kind = Lang.univ_t 1 in
  Lang.add_operator "on_offset"
    [ "offset", Lang.float_t,
      Some (Lang.float (-1.)),
      Some "Execute handler when position in track is equal or \
            more than to this value." ;
      "force", Lang.bool_t,
      Some (Lang.bool false),
      Some "Force execution of callback if track ends before 'offset' \
            position has been reached.";
      "override", Lang.string_t,
      Some (Lang.string "liq_on_offset"),
      Some "Metadata field which, if present and containing a float, overrides the \
            'offset' parameter." ;
      "",
      Lang.fun_t [false,"",Lang.metadata_t] Lang.unit_t,
      None,
      Some "Function to execute. Executed with latest metadata.";
      "", Lang.source_t kind, None, None ]
    ~category:Lang.TrackProcessing
    ~descr:"Call a given handler when position in track is equal or \
            more than a given amount of time."
    ~kind:(Lang.Unconstrained kind)
    (fun p kind ->
       let offset = Lang.to_float (List.assoc "offset" p) in
       let force = Lang.to_bool (List.assoc "force" p) in
       let override = Lang.to_string (List.assoc "override" p) in
       let f = Lang.assoc "" 1 p in
       let s = Lang.to_source (Lang.assoc "" 2 p) in
         new on_offset ~kind ~offset ~force ~override f s)
