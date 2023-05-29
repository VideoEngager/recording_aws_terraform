 resource "aws_eip" "eip" {
   vpc    = true
   count  = var.use_elastic_ip ? (local.use_turn_nodes ? local.turn_nodes : local.kurento_nodes) : 0
#    lifecycle {
#      prevent_destroy = true
#    }
 }


