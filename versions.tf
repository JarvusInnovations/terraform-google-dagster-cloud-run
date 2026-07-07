terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.0"
    }
    # Several resources (webserver IAP, daemon Worker Pool, consolidated
    # service) use provider = google-beta; declare it so consumers get the
    # right provider wiring from the registry.
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 7.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}
