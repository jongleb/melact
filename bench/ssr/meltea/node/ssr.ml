let prepare rows = { Page.count = 0; rows = Array.to_list rows; selection = Page.Unselected }
let render model = Program.render ~view:Page.view model
