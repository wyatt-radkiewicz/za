
SECTIONS {{
  .vectors : {{
    *(.vectors)
  }} >{[region]s}

  .text : {{
    *(.text*)
  }} >{[region]s}

  .exidx : {{
    *(*exidx*)
  }} >{[region]s}

  .extab : {{
    *(*extab*)
  }} >{[region]s}

  .rodata : {{
    *(.rodata*)
    __data_start = .;
  }} >{[region]s}

}}

