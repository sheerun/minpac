let s:results = []

function! minpac#status#get() abort
  let l:update_info = minpac#impl#update_information()
  let l:result = []
  for l:name in keys(g:minpac#pluglist)
    let l:pluginfo = g:minpac#pluglist[l:name]
    let l:dir = l:pluginfo.dir
    let l:plugin = { 'name': l:name, 'lines': [], 'status': '' }

    if !isdirectory(l:dir)
      let l:plugin.status = 'Not installed'
    else
      let l:commits = minpac#impl#system([g:minpac#opt.git, '-C', l:dir, 'log',
            \ '--color=never', '--pretty=format:%h %s (%cr)', '--no-show-signature', 'HEAD...HEAD@{1}'
            \ ])

      let l:plugin.lines = filter(l:commits[1], {-> v:val !=? '' })

      if !l:update_info.update_ran
        let l:plugin.status = 'OK'
      elseif get(l:pluginfo, 'revision') !=? '' && l:pluginfo.revision !=# minpac#impl#get_plugin_revision(l:name)
        let l:plugin.status = 'Updated'
      elseif has_key(l:pluginfo, 'installed') && l:pluginfo.installed ==? 0
        let l:plugin.status = 'Installed'
      endif
    endif

    call add(l:result, l:plugin)
  endfor

  " Show items with most lines (commits) first.
  call sort(l:result, { first, second -> len(second.lines) - len(first.lines) })
  let s:results = l:result

  let l:content = []

  if l:update_info.update_ran
    call add(l:content, l:update_info.updated. ' updated. '.l:update_info.installed. ' installed.')
  endif

  for l:item in l:result
    if l:item.status ==? ''
      continue
    endif

    call add(l:content, '- '.l:item.name.' - '.l:item.status)
    for l:line in l:item.lines
      call add(l:content, ' * '.l:line)
    endfor
  endfor

  let l:content = join(l:content, "\<NL>")
  silent exe 'vertical topleft new'
  setf minpac
  silent exe 'put! =l:content|norm!gg'
  call s:syntax()
  call s:mappings()
  setlocal buftype=nofile bufhidden=wipe nobuflisted nolist noswapfile nowrap cursorline nomodifiable nospell
endfunction


function! s:syntax() abort
  syntax clear
  syn match minpacDash /^-/
  syn match minpacName /\(^- \)\@<=.*/ contains=minpacStatus
  syn match minpacStatus /\(-.*\)\@<=-\s.*$/ contained
  syn match minpacStar /^\s\*/ contained
  syn match minpacCommit /^\s\*\s[0-9a-f]\{7,9} .*/ contains=minpacRelDate,minpacSha,minpacStar
  syn match minpacSha /\(\s\*\s\)\@<=[0-9a-f]\{4,}/ contained
  syn match minpacRelDate /([^)]*)$/ contained

  hi def link minpacDash    Special
  hi def link minpacStar    Boolean
  hi def link minpacName    Function
  hi def link minpacSha     Identifier
  hi def link minpacRelDate Comment
  hi def link minpacStatus  Constant
endfunction

function! s:mappings() abort
  nnoremap <silent><buffer><CR> :call <SID>openSha()<CR>
  nnoremap <silent><buffer>q :q<CR>
  nnoremap <silent><buffer><C-j> :call <SID>nextPackage()<CR>
  nnoremap <silent><buffer><C-k> :call <SID>prevPackage()<CR>
endfunction

function! s:nextPackage()
  return search('^-\s.*$')
endfunction

function! s:prevPackage()
  return search('^-\s.*$', 'b')
endfunction

function s:openSha() abort
  let l:sha = matchstr(getline('.'), '^\s\*\s\zs[0-9a-f]\{7,9}')
  if empty(l:sha)
    return
  endif

  let l:name = s:find_name_by_sha(l:sha)

  if empty(l:name)
    return
  endif

  let l:pluginfo = g:minpac#pluglist[l:name]
  exe 'pedit' l:sha
  wincmd p
  setlocal previewwindow filetype=git buftype=nofile nobuflisted modifiable
  let l:sha_content = minpac#impl#system([g:minpac#opt.git, '-C', l:pluginfo.dir, 'show',
            \ '--no-color', '--pretty=medium', l:sha
            \ ])
  let l:sha_content = join(l:sha_content[1], "\<NL>")

  silent exe 'put! =l:sha_content|norm!gg'
  setlocal nomodifiable
  nnoremap <silent> <buffer> q :q<cr>
endfunction

function! s:find_name_by_sha(sha) abort
  for l:result in s:results
    for l:commit in l:result.lines
      if l:commit =~? '^'.a:sha
        return l:result.name
      endif
    endfor
  endfor

  return ''
endfunction

" vim: set ts=8 sw=2 et:
