/**
 * Copyright 2016 - 2021 Crunchy Data Solutions, Inc.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

/**
 * pgbouncer-install.sql creates the general infrastructure for using pgBouncer
 * with the PostgreSQL Operator
 * This is intended to be executed in the "template1" file as well as any
 * database that exists at the time this script is being executed.
 */


/**
 * We also want to explicitly ensure that the pgbouncer user can only
 * access its one function, to be defined further down. This means
 * explicitly revoking all privileges from the public schema
 *
 * It's fine to execute this every time we init. If for some reason, the user
 * wants to have the pgbouncer user access the public schema...well, open up
 * an issue on GitHub and we can chat.
 */
REVOKE ALL PRIVILEGES ON SCHEMA public FROM auth_user;

/**
 * All of the administrative functions for pgbouncer will live in its own
 * schema, conveniently titled "pgbouncer"
 */
CREATE SCHEMA IF NOT EXISTS auth_user;
/**
 * ...but even though pgbouncer gets its own schema, lock down what it can do
 * on it
 */
REVOKE ALL PRIVILEGES ON SCHEMA auth_user FROM auth_user;
GRANT USAGE ON SCHEMA auth_user TO auth_user;

/**
 * The "get_auth" function allows us to return the appropriate login credentials
 * for a user that is using a password based authentication method so it can work
 * with pgbouncer's "auth_query" parameter.
 *
 * See: http://www.pgbouncer.org/config.html#auth_query
 */
CREATE OR REPLACE FUNCTION auth_user.get_auth(username TEXT)
RETURNS TABLE(username TEXT, password TEXT) AS
$$
  SELECT rolname::TEXT, rolpassword::TEXT
  FROM pg_authid
  WHERE
    /** NOT pg_authid.rolsuper AND */
    NOT pg_authid.rolreplication AND
    pg_authid.rolcanlogin AND
    pg_authid.rolname <> 'auth_user' AND (
      pg_authid.rolvaliduntil IS NULL OR
      pg_authid.rolvaliduntil >= CURRENT_TIMESTAMP
    ) AND
    pg_authid.rolname = $1;
$$
LANGUAGE SQL STABLE SECURITY DEFINER;

/**
 * As mentioned, the pgbouncer user will only be able to access its one function
 * and all it can do is execute. Here is where it does exactly that
 */
REVOKE ALL ON FUNCTION auth_user.get_auth(username TEXT) FROM PUBLIC, auth_user;
GRANT EXECUTE ON FUNCTION auth_user.get_auth(username TEXT) TO auth_user;
