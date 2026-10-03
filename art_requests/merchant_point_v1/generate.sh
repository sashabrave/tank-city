#!/bin/zsh
# Exploded part sheets for the merchant route point (orthographic front + side per part), GPT Image 2.5.
cd "${0:A:h}/../.."
A=art_requests/merchant_point_v1
STYLE="Model-sheet style for a 3D artist: plain flat light-grey background, every part shown in TWO orthographic views side by side (FRONT view and SIDE view), same scale for all parts on the sheet, parts separated with clear space, no perspective, no shadows on the background. Cute, slightly exaggerated cartoon proportions (chunky, a bit squat and top-heavy, oversized rounded details), clean low-poly forms with soft rounded bevels on every edge, soft pastel palette: sage green, cream, warm wood, soft orange stripes, small polished metal parts. No text, no letters, no labels, no numbers, no arrows."
gen(){ local out=$1; shift
  local url=$(higgsfield generate create gpt_image_2_5 --quality high --resolution 4k --aspect_ratio 3:2 --image-references $A/ref/concept.png "$@" --wait --wait-timeout 20m 2>&1 | grep -Eo 'https://[^ ]+\.png' | tail -1)
  [ -z "$url" ] && { echo "FAILED $out"; return 1; }
  curl -sSL -o "$out" "$url" && echo "OK $out"; }
gen $A/ref/parts_stall.png --prompt "Exploded parts of the market stall from the reference image, each part in front and side orthographic views. Parts: 1 the round low tile base with a soft bevelled rim (sandy top, olive side); 2 the wooden counter box with plank front and a thick rounded top board; 3 the four chunky wooden posts; 4 the arched striped awning (orange and cream stripes, scalloped front edge, slightly puffy cartoon canvas); 5 a little hanging lantern on an L-shaped iron bracket post. $STYLE" &
gen $A/ref/parts_props.png --prompt "Exploded small props for the market stall from the reference image, each in front and side orthographic views: 1 a shallow wooden crate full of round goods (oranges, tins); 2 a stacked wooden supply crate with metal corners; 3 an olive ammo box with a handle; 4 a small polished steel barrel; 5 a little cream jar and a bottle; 6 a small low-poly pine tree and a rounded grey rock; 7 a tiny wooden price sign on a stick. $STYLE" &
wait
