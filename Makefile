terraform_version = 0.15.2

init: terraform
	@./terraform init

terraform:
	@if [ -e terraform.zip ]; then rm -f terraform.zip; fi
	@if [ "`uname`" = "Darwin" ]; then\
	  echo "Downloading OSX Terraform";\
	  curl -o terraform.zip https://releases.hashicorp.com/terraform/${terraform_version}/terraform_${terraform_version}_darwin_amd64.zip 2>/dev/null;\
	else \
	  echo "Downloading Linux Terraform";\
	  curl -o terraform.zip https://releases.hashicorp.com/terraform/${terraform_version}/terraform_${terraform_version}_linux_amd64.zip;\
	fi
	@unzip terraform.zip 2>/dev/null
	@if [ -e terraform.zip ]; then rm -f terraform.zip; fi

fmt: terraform
	@./terraform fmt -recursive

plan: init fmt
	@./terraform plan \
		-out "plan.tfplan"

apply: init
	@./terraform apply plan.tfplan

.PHONY: init plan fmt apply
