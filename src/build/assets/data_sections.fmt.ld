
SECTIONS {{
  .data : AT(__data_start) {{
    __data_dest = .;
    *(.data*)
  }} >{[region]s}
  __data_end = __data_start + SIZEOF(.data);

  .bss (NOLOAD) : {{
    __bss_start = .;
    *(.bss*)
    __bss_end = .;
  }} >{[region]s}
}}

