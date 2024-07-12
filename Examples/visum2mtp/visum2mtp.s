init size=5
read file=input\matrix_bi_format.mtx; format=visum; ids=1
read file=input\matrix_bk_format.mtx; format=visum; ids=2
read file=input\matrix_bl_format.mtx; format=visum; ids=3
write matrices=1; file=output\matrix_bi_format.mtp; format=mtp; prec=4
write matrices=2; file=output\matrix_bk_format.mtp; format=mtp; prec=4
write matrices=3; file=output\matrix_bl_format.mtp; format=mtp; prec=4
write matrices=1-3; file=output\matrices_all_formats.mtp; format=mtp; prec=4
