Mirum est notare quam littera gothica,
quam nunc putamus parum claram, anteposuerit litterarum formas humanitatis per seacula
quarta decima et quinta decima. Eodem modo typi, qui nunc nobis videntur parum clari,
fiant sollemnes in futurum.  

    for ( int i = 0; i<lines; i++ ){
      fprintf(stderr, "%04x ",i*8);
      { unsigned char* p = buf + i*8;                 // abstract to dump_line/bytes
        unsigned buflen  = len - i*8;
        unsigned bytes   = MIN(buflen,8);

        for ( int i = 0; i<bytes; i++ ){
          fprintf(stderr, " %02x", *(p+i));
        }
      }
      fprintf(stderr, "\n");      
    }

Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed diam nonummy nibh euismod
tincidunt ut laoreet dolore magna aliquam erat volutpat. Ut wisi enim ad minim veniam,
quis nostrud exerci tation ullamcorper suscipit lobortis nisl ut aliquip ex ea commodo
consequat.
