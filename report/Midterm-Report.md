# Midterm Report – Phase 2
Course: CSE 412
Team: Cole Patola, Svar Ajwani, Mohsin Zaidi, Nassim Zitouni

## 1. ER-to-Relational (DDL)
explain here

## 2. Fill the database with data
explain here

## 3. SQL Queries
explain here

## 4. How to Reproduce
1. start your db

2. run the following command:
psql -h /tmp -p 8888 -d "$USER" -v ON_ERROR_STOP=1 \
  -f demo/phase2_demo.sql \
  -o report/phase2_output.txt


