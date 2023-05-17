 resource "aws_eip" "eip" {
   vpc    = true
   count  = var.use_elastic_ip ? local.kurento_nodes : 0
#    lifecycle {
#      prevent_destroy = true
#    }
 }


