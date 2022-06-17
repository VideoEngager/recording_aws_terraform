 resource "aws_eip" "eip" {
   vpc    = true
   count  = var.use_elastic_ip ? var.nodes_count : 0
#    lifecycle {
#      prevent_destroy = true
#    }
 }


