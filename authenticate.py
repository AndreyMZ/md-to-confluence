#! python3
import getpass
import sys
from typing import Tuple

import keyring

def authenticate(service_name: str, default_username: str = None) -> Tuple[str, str]:
	username = default_username if (default_username is not None) else getpass.getuser()
	sys.stdout.write('User [{0}]: '.format(username))
	sys.stdout.flush()
	line = sys.stdin.readline().rstrip('\n')
	if len(line) != 0:
		username = line

	try:
		password = keyring.get_password(service_name, username)
		keyring_exception = None
	except RuntimeError as ex:
		password = None
		keyring_exception = ex
	prompt = 'Password [******]: ' if password is not None else 'Password: '
	line = getpass.getpass(prompt)
	if (len(line) != 0) or password is None:

		sys.stdout.write('Save password [y/N]: ')
		sys.stdout.flush()
		if sys.stdin.readline().rstrip('\n').lower() == 'y':
			if keyring_exception is None:
				keyring.set_password(service_name, username, line)
			else:
				print(str(keyring_exception))
				sys.stdout.write('Passward was not saved. Press Enter to continue.')
				sys.stdout.flush()
				sys.stdin.readline()
		else:
			if password is not None:
				keyring.delete_password(service_name, username)

		password = line

	return username, password

def delete_password(service_name: str, username: str = None) -> None:
	if username is None:
		username = getpass.getuser()
	try:
		keyring.delete_password(service_name, username)
	except keyring.errors.PasswordDeleteError as ex:
		pass
