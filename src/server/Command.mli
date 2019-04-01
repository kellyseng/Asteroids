module FromClient : sig

type t =
  |CONNECT of string (** user *)
  |EXIT of string (** user *)
  |NEWCOM of float * int (** angle/thrust *)
  |UNRECOGNIZED

val of_string : string -> t

end

module FromServer : sig

type t =
  |WELCOME of string * (string * int) list * (float * float) (** user/scores/coord *)
  |DENIED
  |NEWPLAYER of string (** user *)
  |PLAYERLEFT of string (** user *)
  |SESSION of (string * (float * float)) list * (float * float) (** coords/coord *)
  |WINNER of (string * int) list (** scores *)
  |TICK of (string * (float * float) * (float * float) * float ) list (** vcoords *)
  |NEWOBJ of (float * float) * (string * int) list (** coord/scores *)

val string_of_scores : (string * int) list -> string

val string_of_coords : (string * (float * float)) list -> string

val string_of_vcoords : (string * (float * float) * (float * float) * float) list -> string

val to_string : t -> string

end
