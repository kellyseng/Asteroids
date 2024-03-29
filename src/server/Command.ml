type user = string
type scores = (string * int) list
type coord = (float * float)
type coords = (string * (float * float)) list
type vcoords = (string * (float * float) * (float * float) * float) list

module FromClient = struct

type t =
  |CONNECT of user
  |EXIT of user
  |NEWCOM of float * int (** angle/thrust *)
  |UNRECOGNIZED

let of_string cmd =
  match String.split_on_char '/' cmd with
  |"CONNECT"::name::_ -> CONNECT(name)
  |"EXIT"::name::_ -> EXIT(name)
  |"NEWCOM"::comms::_ -> (if comms.[0] = 'A' (** A or T *)
                          then match String.split_on_char 'T' comms with
                                |[a_to_float; to_int] -> NEWCOM( (float_of_string (String.sub a_to_float 1 ((String.length a_to_float) - 1))),
                                                                 (int_of_string to_int))
                                |_ -> UNRECOGNIZED
                          else match String.split_on_char 'A' comms with
                                |[to_float; t_to_int] -> NEWCOM( (float_of_string to_float),
                                                                 (int_of_string (String.sub t_to_int 1 (String.length t_to_int))))
                                |_ -> UNRECOGNIZED)
  |_ -> UNRECOGNIZED

end

module FromServer = struct

type t =
  |WELCOME_COMP of user * scores * coord * (float * float) list
  |WELCOME of user * scores * coord * coords
  |DENIED
  |NEWPLAYER of user
  |PLAYERLEFT of user
  |SESSION_COMP of coords * coord * (float * float) list
  |SESSION of coords * coord * coords
  |WINNER of scores
  |TICK_COMP of vcoords
  |TICK of vcoords * vcoords
  |NEWOBJ of coord * scores

let string_of_scores scores =
  let rec loop scores acc =
    match scores with
    |[] -> acc
    |(user,score)::[] -> acc ^ user ^ ":" ^ (string_of_int score)
    |(user,score)::tl -> loop tl (acc ^ user ^ ":" ^ (string_of_int score) ^ "|")
  in loop scores ""

let string_of_coords coords =
  let rec loop coords acc =
    match coords with
    |[] -> acc
    |(user,(x,y))::[] -> Printf.sprintf "%s%s:X%fY%f" acc user x y
    |(user,(x,y))::tl -> loop tl (Printf.sprintf "%s%s:X%fY%f|" acc user x y)
  in loop coords ""

let string_of_coords_no_name coords =
  let rec loop coords acc =
    match coords with
    |[] -> acc
    |(x,y)::[] -> Printf.sprintf "%sX%fY%f" acc x y
    |(x,y)::tl -> loop tl (Printf.sprintf "%sX%fY%f|" acc x y)
  in loop coords ""

let string_of_vcoords vcoords =
  let rec loop vcoords acc =
    match vcoords with
    |[] -> acc
    |(user,(x,y),(vx,vy),angle)::[] -> Printf.sprintf "%s%s:X%fY%fVX%fVY%fT%f" acc user x y vx vy angle
    |(user,(x,y),(vx,vy),angle)::tl -> loop tl (Printf.sprintf "%s%s:X%fY%fVX%fVY%fT%f|" acc user x y vx vy angle)
  in loop vcoords ""

let to_string cmd =
  match cmd with
  |WELCOME_COMP(user, scores, (x,y), ocoords) -> Printf.sprintf "WELCOME/%s/%s/X%fY%f/%s/\n" !Values.phase (string_of_scores scores) x y (string_of_coords_no_name ocoords)
  |WELCOME(user, scores, (x,y), coords) -> Printf.sprintf "WELCOME/%s/%s/X%fY%f/%s/\n" !Values.phase (string_of_scores scores) x y (string_of_coords coords)
  |DENIED -> "DENIED/\n"
  |NEWPLAYER user -> "NEWPLAYER/" ^ user ^ "/\n"
  |PLAYERLEFT user -> "PLAYERLEFT/" ^ user ^ "/\n"
  |SESSION_COMP(coords_players, (x,y), coords_asteroids) -> Printf.sprintf "SESSION/%s/X%fY%f/%s/\n" (string_of_coords coords_players) x y (string_of_coords_no_name coords_asteroids)
  |SESSION(coords_players, (x,y), coords_asteroids) -> Printf.sprintf "SESSION/%s/X%fY%f/%s/\n" (string_of_coords coords_players) x y (string_of_coords coords_asteroids)
  |WINNER scores -> "WINNER/" ^ (string_of_scores scores) ^ "/\n"
  |TICK_COMP vcoords -> "TICK/" ^ (string_of_vcoords vcoords) ^ "/\n"
  |TICK(vcoords_players, vcoords_asteroids) -> "TICK/" ^ (string_of_vcoords vcoords_players) ^ "/" ^ (string_of_vcoords vcoords_asteroids) ^ "/\n"
  |NEWOBJ((x,y), scores) ->  Printf.sprintf "NEWOBJ/X%fY%f/%s/\n" x y (string_of_scores scores)

end
