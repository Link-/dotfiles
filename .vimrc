" pathogen
execute pathogen#infect()

" Nerdtree
" autocmd vimenter * NERDTree

" syntax
syntax on
filetype plugin indent on

" Columns
:set cursorline
:set cursorcolumn
:set colorcolumn=80
:colorscheme apprentice
:hi CusorLine  guibg=#2d2d2d

" Mapping
:inoremap § <Esc>

" Indentation
:set ts=2 expandtab
:set shiftwidth=2
:set softtabstop=2

" UI
:set guifont=Envy\ Code\ R:h10
:set laststatus=2
:set statusline+=%F\ %l\:%c
:set ruler
:set relativenumber
:set number

" Watson quick edits
nnoremap <silent> <leader>g 6G2f:lcw
nnoremap <silent> <leader>h 7G2f:lcw

let g:lightline = {
      \ 'colorscheme': 'wombat',
      \ 'active': {
      \   'left': [ [ 'mode', 'paste' ],
      \             [ 'fugitive', 'readonly', 'filename', 'modified' ] ]
      \ },
      \ 'component': {
      \   'readonly': '%{&filetype=="help"?"":&readonly?"x":""}',
      \   'modified': '%{&filetype=="help"?"":&modified?"+":&modifiable?"":"-"}',
      \   'fugitive': '%{exists("*fugitive#head")?fugitive#head():""}'
      \ },
      \ 'component_visible_condition': {
      \   'readonly': '(&filetype!="help"&& &readonly)',
      \   'modified': '(&filetype!="help"&&(&modified||!&modifiable))',
      \   'fugitive': '(exists("*fugitive#head") && ""!=fugitive#head())'
      \ },
      \ 'separator': { 'left': '', 'right': '' },
      \ 'subseparator': { 'left': '|', 'right': '|' }
      \ }
