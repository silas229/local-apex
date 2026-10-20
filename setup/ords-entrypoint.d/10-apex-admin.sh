#!/bin/bash
set -euo pipefail

marker=/etc/ords/config/.apex-admin-configured
if [[ -f "$marker" ]]; then
    exit 0
fi

: "${APEX_ADMIN_PASSWORD:?Set APEX_ADMIN_PASSWORD in setup/ords.env}"
if [[ ! "$APEX_ADMIN_PASSWORD" =~ ^[a-zA-Z0-9_]{16,128}$ ]]; then
    echo "ERROR: APEX_ADMIN_PASSWORD must contain 16-128 letters, digits or underscores." >&2
    exit 1
fi

sql -s /nolog <<SQL
whenever oserror exit failure
whenever sqlerror exit failure rollback
connect sys/"${ORACLE_PWD}"@${DBHOST}:${DBPORT}/${DBSERVICENAME} as sysdba
set define off
begin
    apex_instance_admin.create_or_update_admin_user(
        p_username => 'ADMIN',
        p_email => 'admin@example.com',
        p_password => '${APEX_ADMIN_PASSWORD}');
    commit;
end;
/
exit success
SQL

touch "$marker"
