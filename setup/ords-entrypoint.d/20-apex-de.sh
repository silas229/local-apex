#!/bin/bash
set -euo pipefail

export NLS_LANG=AMERICAN_AMERICA.AL32UTF8
marker=/etc/ords/config/.apex-de-26.2.0-configured
log=/etc/ords/config/apex-de-26.2.0-install.log
rm -f "$marker"

install_german=${APEX_INSTALL_GERMAN:-true}
case "${install_german,,}" in
    true|1|yes)
        ;;
    false|0|no)
        touch "$marker"
        echo "INFO: German APEX translation installation is disabled."
        exit 0
        ;;
    *)
        echo "ERROR: APEX_INSTALL_GERMAN must be true or false." >&2
        exit 1
        ;;
esac

trap 'echo "ERROR: German APEX installation failed. See /etc/ords/config/apex-de-26.2.0-install.log." >&2' ERR

cd /opt/oracle/apex/builder/de

check_german() {
    sql -s /nolog <<SQL
whenever oserror exit failure
whenever sqlerror exit failure rollback
connect sys/"${ORACLE_PWD}"@${DBHOST}:${DBPORT}/${DBSERVICENAME} as sysdba
set heading off feedback off pagesize 0 verify off
declare
    l_version varchar2(30);
begin
    select version into l_version from dba_registry where comp_id='APEX' and status='VALID';
    if l_version <> '26.2.0' then
        raise_application_error(-20001, 'Expected a valid APEX 26.2.0 installation.');
    end if;
end;
/
select 'APEX_DE_COUNT=' || count(*)
  from apex_260200.wwv_flow_language_map m
  join apex_260200.wwv_flows f
    on f.id=m.translation_flow_id and f.security_group_id=m.security_group_id
 where m.translation_flow_language_code='de'
   and m.security_group_id=10
   and m.translation_flow_id in
       (4003,4023,4053,4103,4158,4303,4323,4353,4414,4473,4503,4553,4603,4653,4703,4753);
exit success
SQL
}

check_german > "$log" 2>&1
if grep -qE '^[[:space:]]*APEX_DE_COUNT=16[[:space:]]*$' "$log"; then
    echo "INFO: All 16 German APEX 26.2 applications are already installed."
    touch "$marker"
    exit 0
fi

echo "INFO: Installing German APEX 26.2 applications. Log: $log"
sql -s /nolog >> "$log" 2>&1 <<SQL
whenever oserror exit failure
whenever sqlerror exit failure rollback
connect sys/"${ORACLE_PWD}"@${DBHOST}:${DBPORT}/${DBSERVICENAME} as sysdba
alter session set current_schema=APEX_260200;
@load_de.sql
exit success
SQL

# Oracle's language scripts can reset WHENEVER SQLERROR to CONTINUE.
if grep -nE 'ORA-[0-9]+|PLS-[0-9]+|SP2-[0-9]+|SQL Error|Error starting|Error report' "$log"; then
    echo "ERROR: SQL errors occurred while installing German APEX translations." >&2
    exit 1
fi

result=$(check_german 2>> "$log")
printf '%s\n' "$result" >> "$log"
if ! grep -qE '^[[:space:]]*APEX_DE_COUNT=16[[:space:]]*$' <<< "$result"; then
    echo "ERROR: The German APEX installation is incomplete. See $log." >&2
    exit 1
fi

touch "$marker"
echo "INFO: All 16 German APEX 26.2 applications have been installed."
