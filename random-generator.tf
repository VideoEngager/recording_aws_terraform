resource "random_string" "random_username" {
  length           = 16
  special          = true
  override_special = "_"
}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "_"
}