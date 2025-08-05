data "external" "fleet_token" {
  program = ["bash", "${path.module}/get_fleet_token.sh"]

  query = {
    fleet_url            = local.fleet_url
    fleet_username       = local.fleet_username
    fleet_password       = local.fleet_password
    sensor_instance_name = local.sensor_instance_name
  }

  depends_on = [null_resource.fleet_delay]
}