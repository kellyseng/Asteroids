type t = {mutable id : int; (** mutable for easy delete *)
          mutable coord_x : float; mutable coord_y : float;
          mutable speed_x : float; mutable speed_y : float;
          mutable angle : float}

let thrust_power = Values.thrust_power

let turn_speed = Values.turn_speed

(** default object with id = -1 *)
let fake = {id = -1 ; coord_x = 0. ; coord_y = 0. ; speed_x = 0.; speed_y = 0.; angle = 0.}

(** simply set id to -1 *)
let delete obj = obj.id <- -1

let coords obj = (obj.coord_x, obj.coord_y)

let move obj =
  (match obj.coord_x +. obj.speed_x with
  |x when x >= -.Values.half_width && x < Values.half_width -> obj.coord_x <- x
  |x when x < -.Values.half_width -> obj.coord_x <- x +. 2. *. Values.half_width
  |x -> obj.coord_x <- x +. 2. *. -.Values.half_width); (** when x >= Values.half_width  *)

  match obj.coord_y +. obj.speed_y with
  |y when y >= -.Values.half_height && y < Values.half_height -> obj.coord_y <- y
  |y when y < -.Values.half_height -> obj.coord_y <- y +. 2. *. Values.half_height
  |y -> obj.coord_y <- y +. 2. *. -.Values.half_height (** when y >= Values.half_height  *)

let create id = {id=id; coord_x=((Random.float (2. *. Values.half_width)) -. Values.half_width);
                        coord_y=((Random.float (2. *. Values.half_height)) -. Values.half_height);
                        speed_x=0.;speed_y=0.;angle=0.}

let pi = 4. *. atan 1.

(** commands *)

let turn obj angle = obj.angle <- (obj.angle +. angle)

let accelerate obj thrust =
  obj.speed_x <- obj.speed_x +. (float_of_int thrust) *. (cos obj.angle);
  obj.speed_y <- obj.speed_y +. (float_of_int thrust) *. (sin obj.angle)
