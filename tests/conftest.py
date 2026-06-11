import logging

from infrahouse_core.logging import setup_logging

# "303467602807" is our test account
TEST_ACCOUNT = "303467602807"
# TEST_ROLE_ARN = "arn:aws:iam::303467602807:role/bookstack-tester"
DEFAULT_PROGRESS_INTERVAL = 10

LOG = logging.getLogger(__name__)
TERRAFORM_ROOT_DIR = "test_data"


# Configure the root logger (not just LOG) so progress from library loggers such as
# pytest_infrahouse (e.g. wait_for_instance_refresh) is also streamed during the test.
setup_logging(debug=False)
