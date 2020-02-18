"=============================================================================
" FILE: filter.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu at gmail.com>
" License: MIT license
"=============================================================================

function! denite#filter#is_cmdline_filter_open() abort
  return exists('s:is_cmdline_filter_open') && s:is_cmdline_filter_open
endfunction

function! denite#filter#_open(context, parent, entire_len, is_async) abort
  let denite_statusline = get(b:, 'denite_statusline', {})

  let filter_type = denite#util#get_filter_type(a:context)
  if filter_type !=# 'cmdline'
    let id = win_findbuf(g:denite#_filter_bufnr)
    if !empty(id) && getbufvar(id, '&filetype') ==# 'denite-filter'
      call win_gotoid(id[0])
      call cursor(line('$'), 0)
    else
      call s:new_filter_buffer(a:context)
    endif
  endif

  let g:denite#_filter_parent = a:parent
  let g:denite#_filter_context = a:context
  let g:denite#_filter_entire_len = a:entire_len

  if filter_type ==# 'cmdline'
    let g:denite#_filter_prev_input = a:context['input']

    call s:prepare_cmdline()
    call s:start_timer()
    set concealcursor+=c

    if &lazyredraw
      " Some mappings does not redraw denite window when 'lazyredraw' is on,
      " so ensure to redraw before entering cmdline.
      silent! redraw
    endif

    let s:is_cmdline_filter_open = v:true
    try
      let g:denite#_filter_prev_input = input(a:context['prompt'], a:context['input'])
    catch /^Vim:Interrupt$/
    endtry
    let s:is_cmdline_filter_open = v:false

    set concealcursor-=c
    cmapclear <buffer>

    call s:stop_timer()
  else
    call s:init_buffer()

    let b:denite_statusline = denite_statusline

    " Set the current input
    if getline('$') ==# ''
      call setline('$', a:context['input'])
    else
      call append('$', a:context['input'])
    endif

    if a:context['prompt'] !=# '' && strwidth(a:context['prompt']) <= 2
      call s:init_prompt(a:context)
    endif

    augroup denite-filter
      autocmd!
      autocmd InsertEnter <buffer> call s:start_timer()
      autocmd InsertLeave <buffer> call s:stop_timer()
      autocmd InsertLeave <buffer> call s:update()
    augroup END

    call cursor(line('$'), 0)
    startinsert!

    let g:denite#_filter_prev_input = getline('.')
  endif
endfunction

function! s:init_buffer() abort
  setlocal bufhidden=hide
  setlocal buftype=nofile
  setlocal colorcolumn=
  setlocal foldcolumn=0
  setlocal nobuflisted
  setlocal nofoldenable
  setlocal nolist
  setlocal nomodeline
  setlocal nonumber
  setlocal norelativenumber
  setlocal nospell
  setlocal noswapfile
  setlocal nowrap
  setlocal signcolumn=auto
  setlocal winfixheight

  resize 1

  nnoremap <buffer><silent> <Plug>(denite_filter_update)
        \ :<C-u>call <SID>async_update()<CR>
  inoremap <buffer><silent> <Plug>(denite_filter_update)
        \ <ESC>:call <SID>async_update()<CR>
  nnoremap <buffer><silent> <Plug>(denite_filter_quit)
        \ :<C-u>call <SID>quit(v:true)<CR>
  inoremap <buffer><silent> <Plug>(denite_filter_quit)
        \ <ESC>:<C-u>call <SID>quit(v:true)<CR>
  inoremap <buffer><silent><expr> <Plug>(denite_filter_backspace)
        \ col('.') == 1 ? "a\<BS>" : "\<BS>"

  nmap <buffer> <CR> <Plug>(denite_filter_update)
  nmap <buffer> q    <Plug>(denite_filter_quit)

  imap <buffer> <CR> <Plug>(denite_filter_update)
  imap <buffer> <BS> <Plug>(denite_filter_backspace)
  imap <buffer> <C-h> <Plug>(denite_filter_backspace)

  setfiletype denite-filter
endfunction

function! s:prepare_cmdline() abort
  cnoremap <buffer><silent><expr> <Plug>(denite_filter_update)
        \ [<SID>async_update(), '<ESC>'][-1]
  cnoremap <buffer><silent><expr> <Plug>(denite_filter_quit)
        \ [<SID>quit(v:true), '<ESC>'][-1]
  cnoremap <buffer> <Plug>(denite_filter_backspace)
        \ <BS>

  cmap <buffer> <CR> <Plug>(denite_filter_update)
endfunction

function! s:new_filter_buffer(context) abort
  if denite#util#get_filter_type(a:context) ==# 'floating'
    let row = win_screenpos(win_getid())[0] - 1
    " Note: win_screenpos() == [1, 1] if start_filter
    if row <= 0
      let row = a:context['filter_winrow']
    endif
    let winrow = str2nr(a:context['winrow'])
    let wincol = str2nr(a:context['wincol'])
    if a:context['split'] ==# 'floating'
      call nvim_open_win(bufnr('%'), v:true, {
            \ 'relative': 'editor',
            \ 'row': winrow == 1 ? 0 : row + winheight(0),
            \ 'col': wincol,
            \ 'width': str2nr(a:context['winwidth']),
            \ 'height': 1,
            \})
    else
      call nvim_open_win(bufnr('%'), v:true, {
            \ 'relative': 'editor',
            \ 'row': row + winheight(0) + 1,
            \ 'col': win_screenpos(0)[1],
            \ 'width': winwidth(0),
            \ 'height': 1,
            \})
    endif
    if exists('*bufadd')
      let bufnr = bufadd('denite-filter')
      execute bufnr 'buffer'
    else
      silent edit denite-filter
    endif
    let &l:winhighlight = 'Normal:' . a:context['highlight_filter_background']
  else
    silent execute a:context['filter_split_direction'] 'split' 'denite-filter'
  endif

  let g:denite#_filter_winid = win_getid()
  let g:denite#_filter_bufnr = bufnr('%')
endfunction

function! s:init_prompt(context) abort
  let name = 'denite_filter_prompt'
  let id = 2000
  if exists('*sign_define')
    call sign_define(name, {
          \ 'text': a:context['prompt'],
          \ 'texthl': a:context['highlight_prompt']
          \ })
    call sign_unplace('', {'id': id, 'buffer': bufnr('%')})
    call sign_place(id, '', name, bufnr('%'), {'lnum': line('$')})
  else
    execute printf('sign define %s text=%s texthl=%s',
          \ name, a:context['prompt'], a:context['highlight_prompt'])
    execute printf('silent! sign unplace %d buffer=%s',
          \ id, bufnr('%'))
    execute printf('sign place %d name=%s line=%d buffer=%d',
          \ id, name, line('$'), bufnr('%'))
  endif
endfunction

function! s:get_current_input() abort
  " Returns v:false if user is not in filter window or cmdline
  if &filetype !=# 'denite-filter' && !denite#filter#is_cmdline_filter_open()
    return v:false
  endif

  if denite#filter#is_cmdline_filter_open()
    return getcmdline()
  else
    return getline('.')
  endif
endfunction

function! s:filter_async() abort
  let input = s:get_current_input()

  if input is v:false || input ==# g:denite#_filter_prev_input
    return
  endif

  let g:denite#_filter_prev_input = input

  call denite#util#rpcrequest('_denite_do_async_map',
        \ [g:denite#_filter_parent, 'filter_async', [input]], v:true)
endfunction

function! s:update() abort
  let input = s:get_current_input()

  if input is v:false
    return
  endif

  call denite#filter#_move_to_parent(v:true)

  call denite#call_map('filter', input)

  noautocmd call win_gotoid(g:denite#_filter_winid)
endfunction

function! s:async_update() abort
  let input = s:get_current_input()

  if input is v:false
    return
  endif

  call s:quit(v:false)

  call denite#call_async_map('filter', input)
endfunction

function! s:quit(force_quit) abort
  if a:force_quit
    call s:update()
  endif

  let context = g:denite#_filter_context

  if denite#util#get_filter_type(context) !=# 'cmdline'
    if winnr('$') ==# 1
      buffer #
    elseif a:force_quit || !context['start_filter']
      close!
    endif

    call denite#filter#_move_to_parent(v:false)
  endif

  call s:stop_timer()

  if win_id2win(g:denite#_filter_winid) <= 0
    let g:denite#_filter_winid = -1
  endif
endfunction

function! denite#filter#_move_to_parent(is_async) abort
  let id = win_findbuf(g:denite#_filter_parent)
  if empty(id)
    return
  endif

  if a:is_async
    " Note: noautocmd for statusline flicker
    noautocmd call win_gotoid(id[0])
  else
    call win_gotoid(id[0])
  endif
endfunction
function! denite#filter#_close_filter_window() abort
  if !exists('g:denite#_filter_winid')
        \ || g:denite#_filter_winid < 0
        \ || win_id2win(g:denite#_filter_winid) <= 0
    return
  endif

  let prev = win_getid()

  call win_gotoid(g:denite#_filter_winid)
  close!

  call win_gotoid(prev)
endfunction

function! s:start_timer() abort
  if exists('g:denite#_filter_candidates_timer')
    return
  endif

  let context = g:denite#_filter_context
  if g:denite#_filter_entire_len <
        \ context['max_dynamic_update_candidates'] &&
        \ context['filter_updatetime'] > 0
    let g:denite#_filter_candidates_timer = timer_start(
          \ context['filter_updatetime'],
          \ {-> s:filter_async()}, {'repeat': -1})
  endif
endfunction
function! s:stop_timer() abort
  if !exists('g:denite#_filter_candidates_timer')
    return
  endif

  call timer_stop(g:denite#_filter_candidates_timer)
  unlet g:denite#_filter_candidates_timer
endfunction
