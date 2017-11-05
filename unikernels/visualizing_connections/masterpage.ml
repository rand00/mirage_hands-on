
module Graphics = struct

  open Gg
  open Vg


  let sierpinski = 
    let aspect = 1. in
    let scale = 10. in
    let size = Size2.v
        (aspect *. (110. *. scale))
        (110. *. scale) in
    let view = Box2.v P2.o (Size2.v 5. 5.) 
    in
    let arrowhead_path i len =
      let angle = Float.pi /. 3. in
      let rec loop i len sign turn p =
        if i = 0 then p >> P.line ~rel:true V2.(polar len turn) else
          p >>
          loop (i - 1) (len /. 2.) (-. sign) (turn +. sign *. angle) >>
          loop (i - 1) (len /. 2.) sign turn >>
          loop (i - 1) (len /. 2.) (-. sign) (turn -. sign *. angle)
      in
      P.empty >> loop i len 1. 0.
    in
    let area = `O { P.o with P.width = 0.005 } in
    let gray = I.const (Color.gray 0.2) in
    let acc = ref I.void in
    for i = 0 to 9 do
      let x = float (i mod 2) +. 0.1 in
      let y = 0.85 *. float (i / 2) +. 0.1 in
      acc :=
        gray >> I.cut ~area (arrowhead_path i 0.8) >> I.move (V2.v x y) >>
        I.blend !acc
    done;
    `Image (size, view, !acc)

  module Vector = struct 
  
    let rotate rad v2 = 
      V2.ltr 
        (M2.v 
           (cos rad) (-.sin rad)
           (sin rad) (cos rad))
        v2

    let degree_to_polar d =
      -. (Float.two_pi /. 360.) *. float (d mod 360) 
    
  end 

  module ColorAux = struct

    let darken degree c = Color.blend (Color.v 0. 0. 0. degree) c

  end

  
  module Shapes = struct

    let colors =
      let open Color in
      let a = 1.0 in
      let v = v_srgbi 
      in [
        v 130 77 153 ~a; (*clairvoyant*)
        v 95 135 211 ~a; (*cornflower*)
        v 211 143 95 ~a; (*whiskey*)
        v 135 155 0 ~a; (*yellow green*)

        v 10 77 153 ~a;
        v 95 235 111 ~a;
        v 211 143 9 ~a;
        v 135 55 0 ~a; 
      ]

    let len_colors = List.length colors

    let color_of_index i =
      let c_index = i mod len_colors in (*((i mod len_colors -1) +1) in*) 
      Logs.info (fun f -> f"ACTOR INDEX %d, COLOR INDEX %d" i c_index);
      List.nth colors c_index
    
    let sender i p =
      let color = color_of_index i in
      let path = P.empty >> P.circle P2.o 0.01 in
      I.const color >> I.cut ~area:`Aeo path >>
      I.move p

    let actor = sender

    let receiver i p =
      let color = color_of_index i in
      let w = 0.018 in
      let path = P.empty >> P.rect (Box2.v P2.o (Size2.v w w)) in
      let pos = V2.sub p (V2.half (V2.v w w)) in
      I.const color >> I.cut ~area:`Aeo path >>
      I.move pos

    let connection area color p0 p1 =
      let p = V2.sub p1 p0 in
      let path = P.empty >> P.line p in
      I.const color >> I.cut ~area path >>
      I.move p0
    
    let connection_unviewed =
      let area = `O { P.o with P.width = 0.01 } in
      connection area Color.blue

    let connection_viewed =
      let area = `O { P.o with P.width = 0.005 } in
      connection area (Color.gray 0.3)
    
  end 

  open Types

  let image_of_msg ~radius ~actors type_ (sender_ip, msg) =
    (*goto find index of from-ip and supply to shape*)
    let index_of_ip ip =
      match CCList.find_idx (fun (ip', _) -> ip' = ip) actors with
      | Some (i, _) -> i
      | None -> 0
    in
    let sender_index = index_of_ip sender_ip in
    let p0_angle =
      Vector.degree_to_polar msg.position +. Float.pi_div_2 in
    let p0 = V2.polar radius p0_angle in
    let p1 =  
      match CCList.find_pred (fun (ip, _) -> 
          ip = Ipaddr.V4.of_string_exn msg.to_ip
        ) actors
      with
      | Some (_, Some(a : actor)) ->
        let p1_angle =
          (Vector.degree_to_polar a.position) +. Float.pi_div_2 in
        V2.polar radius p1_angle
      | Some (ip, _) ->
        Logs.info (fun f -> f"P2.o!! (ip %s)" @@ Ipaddr.V4.to_string ip);
        P2.o
      | None ->
        Logs.info (fun f -> f"P2.o!! (Not found)");
        P2.o
    in
    let receiver_index =
      index_of_ip (Ipaddr.V4.of_string_exn msg.to_ip) in
    let connection =
      match type_ with
      | `Viewed -> Shapes.connection_viewed p0 p1
      | `Unviewed -> Shapes.connection_unviewed p0 p1
    in
    List.fold_left I.blend I.void [
      Shapes.sender sender_index p0;
      Shapes.receiver receiver_index p1;
      connection;
    ]

  let visualize ~actors ~viewed ~unviewed =
    let real_height = 1. in
    let aspect = 1.4 in
    let scale = 1.3 *. 110. in
    let size = Size2.v (aspect *. scale) scale in
    let view = Box2.v P2.o (Size2.v aspect real_height) 
    in
    let pad_height = 0.1 in
    let height = 1. -. (2. *. pad_height) in
    let pad_width = 0.15 in
    let width = aspect -. (2. *. pad_width) 
    in
    let radius = height /. 2. in
    let viewed_imgs =
      viewed |> List.map (image_of_msg ~actors ~radius `Viewed)
    and unviewed_imgs =
      unviewed |> List.map (image_of_msg ~actors ~radius `Unviewed) 
    in
    let image =
      I.const @@ Color.gray 0.8
      >> List.fold_right I.blend viewed_imgs 
      >> List.fold_right I.blend unviewed_imgs 
    in
    let center_v2 = V2.(smul 0.5 (v aspect real_height)) in
    let final_image = image >> I.move center_v2
    in
    `Image (size, view, final_image)
    
  let render_svg ~log image =
    let svg = Buffer.create 200 in
    let r = Vgr.create (Vgr_svg.target ()) (`Buffer svg)
    in
    Vgr.render r image |> ignore;
    Vgr.render r `End |> ignore;
    let svg = Buffer.contents svg in
    (*log @@ "svg served:\n" ^ svg;*)
    svg
  
end 

(*todo remove if not using *)
open Tyxml_html
module Svg = Tyxml_svg

let histories_title =
  title (pcdata "Master page.")

let graphics_box ~log =
  let svg_raw = Graphics.(render_svg ~log sierpinski) in
  div ~a:[a_id "vg_area"] [
    Unsafe.data svg_raw
  ]

(*
let graphics_box' ~log =
  let svg_raw = Graphics.(render ~log simple) in
  div ~a:[a_id "vg_area"] [
    svg [
      Svg.
    ]
  ]
*)

(*goto parametrize with inline js-string from vg or?*)
let content ~log ~viewed ~unviewed ~actors =
  html
    (head histories_title [])
    (body [
        h1 [ pcdata "Master page" ];
        graphics_box ~log;
      ])

let to_string content =
  Format.asprintf "%a" (Tyxml.Html.pp ()) content



