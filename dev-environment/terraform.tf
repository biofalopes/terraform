terraform {
  cloud {
    organization = "fabioctba"

    workspaces {
      name = "dev-environment"
    }
  }
}
