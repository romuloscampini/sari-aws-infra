## Requirements

| Name | Version |
|------|---------|
| aws | 2.62 |
| okta | 3.2.0 |
| random | 2.2.1 |

## Providers

| Name | Version |
|------|---------|
| aws | 2.62 |
| okta | 3.2.0 |
| random | 2.2.1 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| ami\_image\_id | The AMI image to create the Bastion Host instance, backed by the https://github.com/aetion/pkr-bastion-host project. | `string` | n/a | yes |
| aws\_region | The primary AWS region name. | `string` | n/a | yes |
| bh\_admin\_key\_passphrase | The passphrase that decrypts the admin user's SSH private key. | `string` | n/a | yes |
| bh\_admin\_username | The Bastion Host user with administration rights (sudoer). | `string` | `"admin"` | no |
| bh\_hostnum | The host address offset to be added to the subnet netmask. For a target CIDR block 10.12.41.0, the offset 123 will result in the IP 10.12.41.123. | `number` | n/a | yes |
| bh\_proxy\_username | The Bastion Host user whose ~/.ssh/authorized\_keys is configured to allow SSH access from end-users. If null or empty, the company's name will be used. | `string` | `null` | no |
| db\_names | The databases names. | `list(string)` | <pre>[<br>  "blackwells",<br>  "whsmith"<br>]</pre> | no |
| environment | The name of the environment, e.g., 'dev', 'prod' etc. It's also tha suffix for the SARI configuration project: sari-cfg-ENV. | `string` | n/a | yes |
| gh\_token | The OAuth token that allows CodeBuild to access the GitHub project's account. | `string` | n/a | yes |
| gh\_user\_or\_org | The GitHub username or organization that owns the SARI configuration project. Defaults to the general organization name. | `string` | `null` | no |
| kms\_decrypt\_keys | List here all KMS keys required to decrypt the SSM-based RDS passwords. | `list(string)` | `[]` | no |
| mysql\_major\_version | The MySQL major & minor version components (X.Y.z) for the RDS instances. | `string` | `"5.7"` | no |
| mysql\_patch\_version | The MySQL patch version (x.y.Z) for the RDS instances. | `string` | `"28"` | no |
| okta\_api\_token | The token to access the Okta API. | `string` | n/a | yes |
| okta\_aws\_app\_iam\_user | The AWS username used by the Okta AWS application to fetch IAM roles. | `string` | n/a | yes |
| okta\_aws\_app\_label | The full name of the Okta AWS Application. | `string` | n/a | yes |
| okta\_org\_name | The organization name in the company's Okta account. Defaults to var.organization value. | `string` | n/a | yes |
| organization | The organization's name. | `string` | n/a | yes |
| sari\_version | The docker tag for the SARI image. | `string` | n/a | yes |
| trusted\_src\_ips | The bastion host will accept SSH connections only from this IP external addresses. | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| bh\_instance\_id | n/a |
| private\_ip | n/a |
| public\_ip | n/a |

