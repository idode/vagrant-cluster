install_mariadb:
  pkg.installed:
    - pkgs:
      - mariadb-server
      - python3-pymysql
      
install_pymysql_for_salt:
  cmd.run:
    - name: /opt/saltstack/salt/bin/python3.14 -m pip install PyMySQL
    - unless: /opt/saltstack/salt/bin/python3.14 -m pip show PyMySQL
    - reload_modules: True

install_saltext_mysql:
  cmd.run:
    - name: /opt/saltstack/salt/bin/python3.14 -m pip install saltext-mysql
    - unless: /opt/saltstack/salt/bin/python3.14 -m pip show saltext-mysql
    - reload_modules: True

mariadb_service:
  service.running:
    - name: mariadb
    - enable: True

slurm_db:
  mysql_database.present:
    - name: slurm_acct_db
    - connection_unix_socket: /var/run/mysqld/mysqld.sock
    - require:
      - cmd: install_pymysql_for_salt
      - cmd: install_saltext_mysql
      - service: mariadb_service
  mysql_user.present:
    - name: slurm
    - password: {{ salt['pillar.get']('slurm:db_password') }}
    - host: localhost
    - connection_unix_socket: /var/run/mysqld/mysqld.sock
  mysql_grants.present:
    - grant: all privileges
    - database: slurm_acct_db.*
    - user: slurm
    - host: localhost
    - connection_unix_socket: /var/run/mysqld/mysqld.sock