open Tyxml_html

let histories_title =
  title (pcdata "Merging histories with Irmin and CRDT's.")

let vector_history_box = div ~a:[a_id "vg_area"] []

(*goto parametrize with inline js-string from vg or?*)
let content ~ip_str =
  html
    (head histories_title [])
    (body [
        h1 [ pcdata ip_str ];
        vector_history_box;
      ])

let to_string content =
  Format.asprintf "%a" (Tyxml.Html.pp ()) content


