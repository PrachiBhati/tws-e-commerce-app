terraform {
  backend "s3" {
    bucket         = "prachi-eks-terraform-state"
    key            = "eks/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-locks"
  }
}
