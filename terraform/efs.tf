resource "aws_efs_file_system" "uploads" {
  creation_token = "${local.prefix}-uploads"
  encrypted      = true

  tags = { Name = "${local.prefix}-uploads" }
}

resource "aws_efs_mount_target" "uploads" {
  count           = 2
  file_system_id  = aws_efs_file_system.uploads.id
  subnet_id       = aws_subnet.app[count.index].id
  security_groups = [aws_security_group.efs.id]
}

# The container runs as uid/gid 1001 (nextjs); the access point forces that identity.
resource "aws_efs_access_point" "uploads" {
  file_system_id = aws_efs_file_system.uploads.id

  posix_user {
    uid = 1001
    gid = 1001
  }

  root_directory {
    path = "/uploads"
    creation_info {
      owner_uid   = 1001
      owner_gid   = 1001
      permissions = "755"
    }
  }

  tags = { Name = "${local.prefix}-uploads-ap" }
}
