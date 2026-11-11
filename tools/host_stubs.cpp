/*
 * host_stubs.cpp - the file, zip and VFS functions the core references, for the native host
 * test (tools/host_test.cpp). As in the blob (pico/pico_stubs.c) they all fail: the ROM is fed
 * as a buffer and nothing is read from or written to files. LoadZip has C++ linkage and takes
 * a uint32, which is unsigned int on x86-64 (unsigned long in the ARM blob).
 */
typedef unsigned long usize;
extern "C" {
void *rfopen(const char *, const char *) { return 0; }
int rfclose(void *) { return -1; }
long long rftell(void *) { return -1; }
long long rfseek(void *, long long, int) { return -1; }
long long rfread(void *, usize, usize, void *) { return 0; }
long long rfwrite(const void *, usize, usize, void *) { return 0; }
char *rfgets(char *, int, void *) { return 0; }
int rfgetc(void *) { return -1; }
int rfputc(int, void *) { return -1; }
long long rfflush(void *) { return 0; }
int rferror(void *) { return 0; }
int rfeof(void *) { return 1; }
int rfprintf(void *, const char *, ...) { return 0; }
int rfscanf(void *, const char *, ...) { return 0; }
void *filestream_open(const char *, unsigned, unsigned) { return 0; }
int filestream_close(void *) { return -1; }
long long filestream_seek(void *, long long, int) { return -1; }
long long filestream_read(void *, void *, long long) { return -1; }
long long filestream_write(void *, const void *, long long) { return -1; }
long long filestream_tell(void *) { return -1; }
long long filestream_read_file(const char *, void **b, long long *l) { if (b) *b = 0; if (l) *l = 0; return 0; }
void vfs_hybrid_init(void *, void *) {}
int zip_archive_open(void *, const char *) { return -1; }
void zip_archive_close(void *) {}
int zip_find_name(const void *, const char *, int) { return -1; }
int zip_find_ext(const void *, const char *, int) { return -1; }
int zip_find_suffix(const void *, const char *, int) { return -1; }
int zip_file_open(void *, void *, int) { return -1; }
void zip_file_close(void *) {}
unsigned zip_file_size(const void *) { return 0; }
unsigned zip_file_read(void *, unsigned, unsigned char *, unsigned) { return 0; }
unsigned char *zip_read_entry(void *, int, unsigned *l) { if (l) *l = 0; return 0; }
}
unsigned char LoadZip(const char *, unsigned int *, unsigned char *) { return 0; }
