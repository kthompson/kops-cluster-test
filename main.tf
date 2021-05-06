terraform {
  required_providers {
    kops = {
      source  = "eddycharly/kops"
      version = "1.19.0-alpha.6"
    }
  }
}

provider "kops" {
  # Configuration options
  state_store = "s3://kevin-test-k8s-cluster"
}

provider "aws" {
  region = "us-west-1"
}

resource "aws_route53_zone" "private" {
  name = "test-k8s"
  vpc {
    vpc_id = aws_vpc.test-k8s.id
  }
}


resource "aws_vpc" "test-k8s" {
  cidr_block       = "10.10.0.0/16"
  instance_tenancy = "default"
  tags = {
    Name = "test-k8s"
  }
}

resource "aws_subnet" "k8s-0" {
  vpc_id            = aws_vpc.test-k8s.id
  cidr_block        = "10.10.1.0/24"
  availability_zone = "us-west-1b"
  tags = {
    Name = "k8s-0"
  }
}

resource "aws_subnet" "k8s-1" {
  vpc_id            = aws_vpc.test-k8s.id
  cidr_block        = "10.10.2.0/24"
  availability_zone = "us-west-1b"
  tags = {
    Name = "k8s-1"
  }
}

resource "aws_subnet" "k8s-2" {
  vpc_id            = aws_vpc.test-k8s.id
  cidr_block        = "10.10.3.0/24"
  availability_zone = "us-west-1a"
  tags = {
    Name = "k8s-2"
  }
}


resource "kops_cluster" "cluster" {
  name               = "cluster.example.com"
  admin_ssh_key      = file("/home/kevin/.ssh/id_rsa.pub")
  cloud_provider     = "aws"
  kubernetes_version = "1.19.10"
  dns_zone           = aws_route53_zone.private.id
  network_id         = aws_vpc.test-k8s.id

  api {
    load_balancer {
      type = "Internal"
      class = "Network"
    }
  }

  docker {
    bridge_ip = "192.168.1.5/24"
  }

  iam {
    allow_container_registry = true
    legacy = false
  }

  networking {
    calico {}
  }

  topology {
    masters = "private"
    nodes   = "private"

    dns {
      type = "Private"
    }
  }

  # cluster subnets
  subnet {
    name        = aws_subnet.k8s-0.tags.Name
    provider_id = aws_subnet.k8s-0.id
    type        = "Private"
    zone        = aws_subnet.k8s-0.availability_zone
  }

  subnet {
    name        = aws_subnet.k8s-1.tags.Name
    provider_id = aws_subnet.k8s-1.id
    type        = "Private"
    zone        = aws_subnet.k8s-1.availability_zone
  }

  subnet {
    name        = aws_subnet.k8s-2.tags.Name
    provider_id = aws_subnet.k8s-2.id
    type        = "Private"
    zone        = aws_subnet.k8s-2.availability_zone
  }

  # etcd clusters
  etcd_cluster {
    name = "main"

    member {
      name           = "master-0"
      instance_group = "master-0"
    }

    member {
      name           = "master-1"
      instance_group = "master-1"
    }

    member {
      name           = "master-2"
      instance_group = "master-2"
    }
  }

  etcd_cluster {
    name = "events"

    member {
      name           = "master-0"
      instance_group = "master-0"
    }

    member {
      name           = "master-1"
      instance_group = "master-1"
    }

    member {
      name           = "master-2"
      instance_group = "master-2"
    }
  }
}

resource "kops_instance_group" "master-0" {
  cluster_name = kops_cluster.cluster.name
  name         = "master-0"
  role         = "Master"
  min_size     = 1
  max_size     = 1
  machine_type = "t3.medium"
  subnets      = [aws_subnet.k8s-0.tags.Name]
  depends_on   = [kops_cluster.cluster]
}

resource "kops_instance_group" "master-1" {
  cluster_name = kops_cluster.cluster.name
  name         = "master-1"
  role         = "Master"
  min_size     = 1
  max_size     = 1
  machine_type = "t3.medium"
  subnets      = [aws_subnet.k8s-1.tags.Name]
  depends_on   = [kops_cluster.cluster]
}

resource "kops_instance_group" "master-2" {
  cluster_name = kops_cluster.cluster.name
  name         = "master-2"
  role         = "Master"
  min_size     = 1
  max_size     = 1
  machine_type = "t3.medium"
  subnets      = [aws_subnet.k8s-2.tags.Name]
  depends_on   = [kops_cluster.cluster]
}

resource "kops_instance_group" "nodes" {
  cluster_name = kops_cluster.cluster.name
  name         = "nodes"
  role         = "Node"
  min_size     = 1
  max_size     = 1
  machine_type = "t3.medium"
  subnets = [
    aws_subnet.k8s-0.tags.Name,
    aws_subnet.k8s-1.tags.Name,
    aws_subnet.k8s-2.tags.Name
  ]
  depends_on = [kops_cluster.cluster]
}

resource "kops_cluster_updater" "updater" {
  cluster_name = kops_cluster.cluster.name

  keepers = {
    cluster  = kops_cluster.cluster.revision,
    master-0 = kops_instance_group.master-0.revision,
    master-1 = kops_instance_group.master-1.revision,
    master-2 = kops_instance_group.master-2.revision
  }
}
