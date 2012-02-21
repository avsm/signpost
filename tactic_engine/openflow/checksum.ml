open Bitstring

let ones_complement data = 
  let rec add count data =
    bitmatch data with
      | {value:16:littleendian; data:-1:bitstring} ->
          (value + (add (count + 1) data)) 
      | { value:8 } -> 
          (value lsl 8)
      | { _ } -> 0
  in 
  let res = add 1 data in 
    if (res > 0xffff) then 
      ((lnot ((res land 0xffff) + (res lsr 16))) land 0xffff)
    else
        ((lnot res) land 0xffff)

