#!/bin/bash
set -euo pipefail

marker=/etc/ords/config/.apex-smtp-configured
rm -f "$marker"
trap 'echo "ERROR: APEX SMTP configuration or connection to mailpit:1025 failed." >&2' ERR

sql -s /nolog <<SQL
whenever oserror exit failure
whenever sqlerror exit failure rollback
connect sys/"${ORACLE_PWD}"@${DBHOST}:${DBPORT}/${DBSERVICENAME} as sysdba
set define off
declare
    l_apex_schema varchar2(128);
begin
    select schema into l_apex_schema
      from dba_registry where comp_id='APEX' and status='VALID';

    dbms_network_acl_admin.append_host_ace(
        host => 'mailpit',
        lower_port => 1025,
        upper_port => 1025,
        ace => xs\$ace_type(
            privilege_list => xs\$name_list('connect'),
            principal_name => l_apex_schema,
            principal_type => xs_acl.ptype_db));

    apex_instance_admin.set_parameter('SMTP_HOST_ADDRESS', 'mailpit');
    apex_instance_admin.set_parameter('SMTP_HOST_PORT', '1025');
    apex_instance_admin.set_parameter('SMTP_TLS_MODE', 'N');
    apex_instance_admin.set_parameter('SMTP_USERNAME', null);
    apex_instance_admin.set_parameter('SMTP_PASSWORD', null);
    apex_instance_admin.set_parameter('SMTP_FROM', 'apex@example.test');
    commit;

    apex_instance_admin.validate_email_config;
end;
/
exit success
SQL

touch "$marker"
echo "INFO: APEX instance SMTP server configured and reachable at mailpit:1025."
