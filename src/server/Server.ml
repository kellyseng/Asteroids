open Player

exception Client_exit
exception Client_denied

let new_player_id = ref 0

let starting = ref false

let ended = ref false

let max_players = Values.max_players

let players = Array.make max_players ((stdin,stdout),Player.default) (** stdin and stdout for default chans *)

let asteroids_ids = Array.make Values.nb_asteroids 0

let make_asteroids () =
  for i = 0 to Values.nb_asteroids - 1 do
    asteroids_ids.(i) <- (Arena.add_object_no_id Values.asteroid_mass Values.asteroid_radius)
  done

let real_players () = List.filter (fun ((_,_),p) -> p.ship_id <> -1) (Array.to_list players)

let scores () = List.map (fun ((_,_),p) -> (p.name,p.score)) (real_players ())

let asteroids_coords_comp () = List.map (fun x -> Object.coords Arena.objects.(x)) (List.filter (fun x -> x <> -1) (Array.to_list asteroids_ids))

let asteroids_coords () = List.map (fun x -> (string_of_int x),Object.coords Arena.objects.(x)) (List.filter (fun x -> x <> -1) (Array.to_list asteroids_ids))

let asteroids_vcoords () = List.map (fun x -> (string_of_int x),Object.coords Arena.objects.(x),(Arena.objects.(x).speed_x,Arena.objects.(x).speed_y),Arena.objects.(x).angle) (List.filter (fun x -> x <> -1) (Array.to_list asteroids_ids))

let message ?(id = (-1)) cmd =
  match id with
  |(-1) -> List.iter (fun x -> output_string (snd (fst x)) (Command.FromServer.to_string cmd)) (real_players ())
  |id -> output_string (snd (fst players.(id))) (Command.FromServer.to_string cmd)

let create_server ip port max_con =
  let sock = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0
  and addr = if ip = "localhost" then Unix.inet_addr_loopback else (Unix.inet_addr_of_string ip) in
  Unix.bind sock (Unix.ADDR_INET(addr, port));
  Unix.listen sock max_con ;
  sock

let refresh_id () =
  let rec loop ind =
    match (snd players.(ind)) with
    |p when p.ship_id = -1 -> new_player_id := ind; true
    |_ -> if ind < max_players then loop (ind + 1) else false
  in loop 0

let server_process sock service =
  while true do
    let (s, caller) = Unix.accept sock
    in
      (if (refresh_id ())
        then begin
          ignore(Thread.create service ((Unix.in_channel_of_descr s,Unix.out_channel_of_descr s),!new_player_id));
          if (not !starting) then starting := true
        end else output_string (Unix.out_channel_of_descr s) (Command.FromServer.to_string (Command.FromServer.DENIED)))
  done

let server_service (chans,id) =
  let inchan = fst chans
  and outchan = snd chans
  in
    try
      while true do
        match Command.FromClient.of_string (input_line inchan) with
        |Command.FromClient.CONNECT(name) ->
          (if (List.exists (fun ((_,_),p) -> p.name = name) (real_players ()))
            then (output_string outchan (Command.FromServer.to_string (Command.FromServer.DENIED)); flush outchan; raise Client_denied)
            else begin
              players.(id) <- ((inchan,outchan), Player.create name);
              (if !Values.compatibility_mode
              then begin
                message ~id:id (Command.FromServer.WELCOME_COMP(name,(scores ()), Object.coords Arena.objects.(Arena.objectif_id), asteroids_coords_comp ()));
                if !Values.phase == "jeu"
                  then begin
                    message ~id:id (Command.FromServer.SESSION_COMP(List.map (fun ((_,_),p) -> (p.name, Player.coords p)) (real_players ()), Object.coords Arena.objects.(Arena.objectif_id), asteroids_coords_comp ()));
                    message ~id:id (Command.FromServer.NEWOBJ(Object.coords Arena.objects.(Arena.objectif_id), scores ()))
                  end
              end else begin
                message ~id:id (Command.FromServer.WELCOME(name,(scores ()), Object.coords Arena.objects.(Arena.objectif_id), asteroids_coords ()));
                if !Values.phase == "jeu"
                  then begin
                    message ~id:id (Command.FromServer.SESSION(List.map (fun ((_,_),p) -> (p.name, Player.coords p)) (real_players ()), Object.coords Arena.objects.(Arena.objectif_id), asteroids_coords ()));
                    message ~id:id (Command.FromServer.NEWOBJ(Object.coords Arena.objects.(Arena.objectif_id), scores ()))
                  end
              end);
              message (Command.FromServer.NEWPLAYER(name));
              (** this flush may conflict with the one from thread game *)
              List.iter (fun ((_,out),_) -> flush out) (real_players ())
            end)
        |Command.FromClient.EXIT(name) ->
          begin
            Arena.remove_object (snd players.(id)).ship_id;
            players.(id) <- ((stdin,stdout),Player.default);
            message (Command.FromServer.PLAYERLEFT(name)); raise Client_exit
          end
        |Command.FromClient.NEWCOM(angle,thrust) -> (Arena.turn (snd players.(id)).ship_id angle; Arena.accelerate (snd players.(id)).ship_id thrust)
        |Command.FromClient.UNRECOGNIZED -> () (** ignore unrecognized command *)
      done
    with
      |Client_exit | Client_denied -> ()
      |_ ->
      begin
        Arena.remove_object (snd players.(id)).ship_id;
        message (Command.FromServer.PLAYERLEFT((snd players.(id)).name));
        players.(id) <- ((stdin,stdout),Player.default)
      end

let game () =
  let tick_before_send = int_of_float (Values.server_refresh_tickrate /.  Values.server_tickrate)
  and tick_count = ref 0 in
  make_asteroids ();
  while true do
    (if (List.length (real_players ())) > 0 then starting := true);
    while (not !starting) do
      Thread.delay 1.
    done;
    Thread.delay Values.countdown;
    Values.phase := "jeu";
    message (Command.FromServer.SESSION(List.map (fun ((_,_),p) -> (p.name, Player.coords p)) (real_players ()), Object.coords Arena.objects.(Arena.objectif_id), asteroids_coords ()));
    while (not !ended) do
      let start = Sys.time () in
      (** check scores *)
      for i = 0 to max_players - 1 do
        if (snd players.(i)).score >= Values.max_score
          then begin
            ended := true;
            message (Command.FromServer.WINNER((scores ())));
          end
      done;
      (** check objectif *)
      let at_least_one = ref false in
      (** we give points to all players touching the objectif *)
      List.iter (fun ((_,_),p) -> if (Player.touching p Arena.objects.(Arena.objectif_id)) then (at_least_one := true;  p.score <- p.score + 1)) (real_players ());
      (if !at_least_one
        then begin
          Arena.add_object Arena.objectif_id 0. Values.objectif_radius;
          message (Command.FromServer.NEWOBJ(Object.coords Arena.objects.(Arena.objectif_id), scores ()))
        end);
      (** check collisions *)
      (if !Values.compatibility_mode
        then List.iter (fun ((_,_),p) -> List.iter (Object.collision_comp Arena.objects.(p.ship_id)) (List.map (fun id -> Arena.objects.(id)) (Array.to_list asteroids_ids))) (real_players ())
        else Arena.collision_all ());
      (** move objects *)
      (if !Values.compatibility_mode
        then Arena.move_all_ids (List.map (fun ((_,_),p) -> p.ship_id) (real_players ()))
        else Arena.move_all ());
      (** sleep during 1 / server_tickrate - calcul_time *)
      let wait_time = 1. /. Values.server_tickrate -. (Sys.time () -. start) in
      (** if wait_time < 0, Values.server_tickrate is too big *)
      (if (wait_time > 0.)
        then Thread.delay (wait_time)
        else print_endline "please decrease Values.server_tickrate");
      (** send message TICK to everyone *)
      (if !tick_count = tick_before_send
        then begin
          (if !Values.compatibility_mode
            then message (Command.FromServer.TICK_COMP(List.map (fun ((_,_),p) -> Player.vcoords p) (real_players ())))
            else message (Command.FromServer.TICK(List.map (fun ((_,_),p) -> Player.vcoords p) (real_players ()), asteroids_vcoords ())));
          tick_count := 0
        end else tick_count := !tick_count + 1);
      (** flush everyone *)
      List.iter (fun ((_,out),_) -> flush out) (real_players ())
    done;
    starting := false;
    ended := false;
    Array.iter Arena.remove_object asteroids_ids;
    List.iter (fun ((_,_),p) -> p.score <- 0; Object.freeze Arena.objects.(p.ship_id)) (real_players ());
    make_asteroids ();
    (if !Values.compatibility_mode
      then message (Command.FromServer.TICK_COMP(List.map (fun ((_,_),p) -> Player.vcoords p) (real_players ())))
      else message (Command.FromServer.TICK(List.map (fun ((_,_),p) -> Player.vcoords p) (real_players ()), asteroids_vcoords ())));
    Values.phase := "attente"
  done

let _ =
  Random.self_init ();
  match Array.length Sys.argv with
  |3 ->
  begin
    let ip = Sys.argv.(1)
    and port = int_of_string Sys.argv.(2) in
    let sock = create_server ip port max_players ; in
    ignore(Thread.create game ());
    server_process sock server_service
  end
  |4 when Sys.argv.(3) = "-comp" ->
  begin
    Values.compatibility_mode := true;
    let ip = Sys.argv.(1)
    and port = int_of_string Sys.argv.(2) in
    let sock = create_server ip port max_players ; in
    ignore(Thread.create game ());
    server_process sock server_service
  end
  |_ -> print_endline "usage :\n\t- server <ip> <port>\n\t- server <port> -comp"
