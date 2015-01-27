#include <stdlib.h>
#include <stdio.h>
#include <unistd.h> // TODO W32 compat
#include <string.h>
#include <mruby.h>
#include <mruby/array.h>
#include <mruby/string.h>
#include <mruby/compile.h>
#include <mruby/error.h>

void init_argv(mrb_state *mrb, int argc, char** argv) {
  int i;
  mrb_value ARGV;

  ARGV = mrb_ary_new_capa(mrb, argc - 1);  
  for(i = 1; i < argc; i++) {
    mrb_ary_push(mrb, ARGV, mrb_str_new(mrb, argv[i], strlen(argv[i])));
  }

  mrb_define_global_const(mrb, "ARGV", ARGV);
}

int main(int argc, char** argv) {
  int rval = 0;
  mrb_state *mrb;
  mrbc_context *c;
  char code[] = "main()";
  struct mrb_parser_state *p;
  struct RProc *proc;

  mrb = mrb_open();
  init_argv(mrb, argc, argv);

  c = mrbc_context_new(mrb);

  mrbc_filename(mrb, c, "k8p");

  p = mrb_parse_string(mrb, code, c);
  proc = mrb_generate_code(mrb, p);
  mrb_context_run(mrb, proc, mrb_top_self(mrb), 0);
  
  if (mrb->exc) {
      mrb_print_error(mrb);
      rval = 1;
  }

  mrbc_context_free(mrb, c);
  mrb_close(mrb);

  return rval;
}