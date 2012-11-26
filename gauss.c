int matrix[MAXDIM][MAXDIM];
pthread_t thread[MAXTHREADS];
struct thread_data data[MAXTHREADS];

void pthread_reduce(void)
{
   for (i = 1; k <= nrows - 1; ++k) {
      for (i = k + 1; i <= nrows; ++i) {
         data[i] = /* Setup worker. */;
         pthread_create(&thread[i], NULL, worker,
            &data[i]);
      }

      /* Bug! Should be i <= nrows */
      for (i = k + 1; i < nrows; ++i) {
         pthread_join(thread[i], NULL);
      }
   }
}

/* Forks a deterministic child. Returns 0 into the child and 1 into the parent. */
int dfork(pid_t childid);
/* Merges a child's changes into the parent after the child issues a dret(). */
void djoin(pid_t childid);

void det_reduce(void)
{
   for (i = 1; k <= nrows - 1; ++k) {
      for (i = k + 1; i <= nrows; ++i) {
         data[i] = /* Setup worker. */;
         if (!dfork(i)) { worker(&data[i]); dret(); }
      }

      /* Bug! Should be i <= nrows */
      for (i = k + 1; i < nrows; ++i) {
         djoin(i);
      }
   }
}

int main(void)
{
   /* Initialize matrix, other variables. */
   parallel_reduce();
   /* Try to access result matrix. */
}
