terraform {
  backend "gcs" {
    bucket = "aef-shahcago-hackathon-tfe"
    prefix = "aef-orchestration-framework/environments/dev"
  }
}