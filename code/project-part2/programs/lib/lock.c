int atomicIncrement( int *pdata )
{
    int ret;
    int address = (int) pdata;
    asm volatile( "ll %0, (%1)"
                    : "=r" (ret)    /* %0 */
                    : "r" (address) /* %1 */ );
    asm volatile( "addiu %0, %1, 1"
                    : "=r" (ret) /* %0 */
                    : "r" (ret)  /* %1 */ );
    asm volatile( "sc %0, (%1)"
                    : "+r" (ret)    /* %0, "+r" denotes a read-write operand */
                    : "r" (address) /* %1 */ );
    /* ret == 1 on success */
    /* ret == 0 on failure */
    return ret;
}

int readAndIncrement( int *pdata, int inc_amount )
{
    int ret, success;
    int address = (int) pdata;
    do {
        asm volatile( "ll %0, (%1)"
                        : "=r" (ret)    /* %0 */
                        : "r" (address) /* %1 */ );
        asm volatile( "addu %0, %1, %2"
                        : "=r" (success)   /* %0 */
                        : "r" (ret),       /* %1 */
                          "r" (inc_amount) /* %2 */ );
        asm volatile( "sc %0, (%1)"
                        : "+r" (success) /* %0, "+r" denotes a read-write operand */
                        : "r" (address)  /* %1 */ );
    } while (success == 0);
    /* success == 1 on success */
    /* success == 0 on failure */
    return ret;
}
