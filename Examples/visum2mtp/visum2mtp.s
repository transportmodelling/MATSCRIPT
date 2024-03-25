init size=5
read file=input\matrix_bi_format.mtx; format=visum; id=1
read file=input\matrix_bk_format.mtx; format=visum; id=2
read file=input\matrix_bl_format.mtx; format=visum; id=3
matrix file=1; index=1; id=1
matrix file=2; index=1; id=2
matrix file=3; index=1; id=3
write matrices=1; file=output\matrix_bi_format.mtp; format=mtp; prec=4
write matrices=2; file=output\matrix_bk_format.mtp; format=mtp; prec=4
write matrices=3; file=output\matrix_bl_format.mtp; format=mtp; prec=4
