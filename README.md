This repo contains the SQL schema (DDL), data loading scripts, and demo queries for our midterm report.

Clone the repository and run the following command to reproduce:

psql -h /tmp -p 8888 -d "$USER" -v ON_ERROR_STOP=1 \
  -f demo/phase2_demo.sql \
  -o report/phase2_output.txt
