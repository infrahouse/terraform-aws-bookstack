# Validation checks to catch issues before deployment

# Note: Userdata size cannot be validated here due to Terraform ordering
# (module outputs aren't available until after the module is applied).
# Instead, we output the size so users can monitor it.
# See outputs.tf for userdata_size_info output.
