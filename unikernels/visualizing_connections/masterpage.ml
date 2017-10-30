
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

  let visualize ~actors ~viewed ~unviewed =
    let aspect = 1.4 in
    let scale = 2.1 *. 110. in
    let size = Size2.v (aspect *. scale) scale in
    let view = Box2.v P2.o (Size2.v aspect 1.) 
    in
    let pad_height = 0.1 in
    let height = 1. -. (2. *. pad_height) in
    let pad_width = 0.15 in
    let width = aspect -. (2. *. pad_width) in
    let area = `O { P.o with P.width = 0.005 *. height }
    in
    let path =
      P.empty 
      >> P.line V2.(v 0.1 0.0) 
      >> P.line V2.(v 0.8 0.8) in
    let image =
      I.const Color.black
      >> I.cut ~area path
      >> I.move V2.(v 0.15 0.1)
    in
    `Image (size, view, image)
    
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



