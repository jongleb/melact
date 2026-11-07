let chunked ?(size = 100) ?(rowHeight = 40) ?(tag = "div") rows =
  React.of_child (Melhole.View.chunks ~size ~row_height:rowHeight ~tag (React.to_child rows))
