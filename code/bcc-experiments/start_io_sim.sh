# --- simulation of ios using FIO ---
# executed using: ./start_io_sim.sh

FIO_JOB_FILE="io_test.fio"
sudo fio "${FIO_JOB_FILE}"