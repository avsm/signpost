#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
#include <arpa/inet.h>
#include <unbound.h>

char strbuffer[1500];

char *
print_hex(const char* str, int len) {
  int i;

  memset(strbuffer, '\0', 1500);

  if(!str)
    return strbuffer;

  for(i = 0 ; i < len; i++) {
    sprintf((strbuffer + 3*i), "%02x:", (uint8_t) str[i]);
  }

  return strbuffer;
}

int main(int argc, char *argv[])
{
  struct ub_ctx* ctx;
  struct ub_result* result;
  int retval, i;

  if(argc < 2) {
    printf("usage: %s hostname\n", argv[0]);
    return 1;
  }

  /*  create context */
  ctx = ub_ctx_create();
  if(!ctx) {
    printf("error: could not create unbound context\n");
    return 1;
  }


  ub_ctx_debuglevel(ctx, 10);

  /*  read /etc/resolv.conf for DNS proxy settings (from DHCP) */
  if( (retval=ub_ctx_resolvconf(ctx, "/etc/resolv.conf")) != 0) {
    printf("error reading resolv.conf: %s. errno says: %s\n", 
        ub_strerror(retval), strerror(errno));
    return 1;
  }
  /*  read /etc/hosts for locally supplied host addresses */
  if( (retval=ub_ctx_hosts(ctx, "/etc/hosts")) != 0) {
    printf("error reading hosts: %s. errno says: %s\n", 
        ub_strerror(retval), strerror(errno));
    return 1;
  }

  /*  read public keys for DNSSEC verification */
  if( (retval=ub_ctx_add_ta_file(ctx, "keys")) != 0) {
    printf("error adding keys: %s\n", ub_strerror(retval));
    return 1;
  }

  /*  query for webserver */
  retval = ub_resolve(ctx, argv[1], 
      48 /*  TYPE A (IPv4 address) */, 
      1 /*  CLASS IN (internet) */, &result);
  if(retval != 0) {
    printf("resolve error: %s\n", ub_strerror(retval));
    return 1;
  }

  /*  show first result */
  if(result->havedata) {
    for (i = 0 ; result->data[i] ; i++) {
      //key contains a few extra bits
      printf("DNSKEY: %s\n",print_hex(result->data[i] + 4, result->len[i] - 4)); 
          //inet_ntoa(*(struct in_addr*)result->data[0]));
    }
  }
  /*  show security status */
  if(result->secure)
    printf("Result is secure\n");
  else if(result->bogus)
    printf("Result is bogus: %s\n", result->why_bogus);
  else  printf("Result is insecure\n");

  ub_resolve_free(result);
  ub_ctx_delete(ctx);
  return 0;
}
