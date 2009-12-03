;;; **************************************************************************
;; @(#) java-find.el -- finds classname at point in SOURCEPATH.
;; @(#) $Id: java-find.el,v 1.4 2001/01/11 02:59:18 root Exp $

;; This file is not part of Emacs

;; Copyright (C) 2000-2001 by Joseph L. Casadonte Jr.
;; Author:          Joe Casadonte (emacs@northbound-train.com)
;; Maintainer:      Joe Casadonte (emacs@northbound-train.com)
;; Created:         August 17, 2000
;; Latest Version:  http://www.northbound-traincom/emacs.html

;; COPYRIGHT NOTICE

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.
;;; **************************************************************************

;;; Description:
;;
;;  This package provides a way to find and visit Java source files (indicated
;;  by a classname or filename under point) located somewhere in the user's
;;  SOURCEPATH.

;;; Installation:
;;
;;  Put this file on your Emacs-Lisp load path and add the following to your
;;  ~/.emacs startup file
;;
;;     (require 'java-find)

;;; Usage:
;;
;;  M-x `joc-java-find-class-at-point'
;;     Visits file (represented by a classname) under point using SOURCEPATH to
;;     determine which file to visit.
;;
;;     If on a stacktrace line (or one formatted like that) it will attempt to
;;     go to the proper line number (e.g. invoking the function on a line such as
;;
;;        com.bar.foo.Baz.write(Baz.java:56)
;;
;;     will attempt to visit Baz.java on line 56).   This function will also attempt
;;     to resolve nested classes properly (adherence to java class naming
;;     conventions is assumed).
;;
;;     As a special case, having point be anywhere on an `import' line is supported,
;;     and it will run dired on `import com.foo.bar.*;' lines, if configured to do
;;     so (see variable joc-java-find-visit-dirs)."
;;
;;     See below for keybinding suggestions.
;;
;;  M-x `joc-java-find-file-at-point'
;;     Looks for and finds the first matching file (or directory) in SOURCEPATH.
;;     If the filename ends in a frontslash (`/'), a directory will be looked
;;     for and visited (depending on the value of joc-java-find-visit-dirs);
;;     otherwise, a file (complete with any extension) is assumed.
;;
;;     See below for keybinding suggestions.

;;; Keybinding suggestions:
;;
;;  I use a simple keystroke for the main function
;;  (joc-java-find-class-at-point), as I find myself doing it often.
;;  You can bind it globally:
;;
;;        (global-set-key [(control return)] 'joc-java-find-class-at-point)
;;
;;  or for specific modes only:
;;
;;        (add-hook 'jde-mode-hook
;;				    (function (lambda ()
;;                           ;; other stuff here
;;							    (define-key jde-mode-map
;;								  [(control return)] 'joc-java-find-class-at-point))))
;;
;;        (add-hook 'compilation-mode-hook
;;				    (function (lambda ()
;;                           ;; other stuff here
;;							    (define-key compilation-mode-map
;;								  [(control return)] 'joc-java-find-class-at-point))))
;;
;;  Personally I find it more useful to bind this globally, so that it
;;  can be used anywhere I find a classname (log files, email,
;;  compilation buffers, source files, scratch buffer, etc).
;;
;;  I also like to keep stray buffers to a minimum, so I bind a
;;  version that will use find-alternate-file instead of find-file; it
;;  lets me follow a series of import statements until I find the
;;  class I'm looking for.  Of course, this works well for me because
;;  I'm fairly pedantic about naming classes explicitly in import
;;  statements.  It's usefulness is more limited on lines like "import
;;  foo.bar.*".  Here's what I have in my .emacs file:
;;
;;      (require 'java-find)
;;      (global-set-key [(control return)] 'joc-java-find-class-at-point)
;;      (global-set-key [(control shift return)] (function
;;      	(lambda () "joc-java-find-alternate-class-at-point"
;;      	  (interactive) (let ((joc-java-find-alt-cmd 'find-alternate-file))
;;      					  (joc-java-find-class-at-point)))))
;;      (global-set-key [(control meta return)] 'joc-java-find-file-at-point)

;;; Customization:
;;
;;  M-x `joc-java-find-customize' to customize all package options.
;;
;;  The following variables can be customized:
;;
;;  o `joc-java-find-visit-dirs'
;;        Boolean used to determine whether or not to visit directories if
;;        that's what's found; for example, running joc-java-find-class-at-point
;;        on an import line such as:
;;
;;             import com.bar.foo.*;
;;
;;        will visit the directory only if joc-java-find-visit-dirs is t.
;;
;;  o `joc-java-find-alt-cmd'
;;        An alternate command to run instead of `find-file' when visiting
;;        source files.
;;
;;  o `joc-java-find-dired-cmd'
;;        An alternate command to run instead of `find-file' when visiting
;;        directories (only when joc-java-find-visit-dirs is t).

;;; To Do:
;;
;;  o Use highlighted region to demark a classname or filename
;;
;;  o phil's stuff:
;;    - goto nested class def
;;    - find class in current package
;;    - find class using current file's import list
;;
;;  o Allow use of jde-*-sourcepath variables, and allow the sequencing of
;;    these variables.
;;
;;  o Allow the stack-trace line number code (and the classname finder) to
;;    work across newlines (useful for stack-traces wrapped to 80 columns).

;;; Comments:
;;
;;  Any comments, suggestions, bug reports or upgrade requests are welcome.
;;  Please send them to Joe Casadonte (emacs@northbound-train.com).
;;
;;  This version of dired-single was developed and tested with NTEmacs 20.5.1
;;  and 2.7 under Windows NT 4.0 SP6 and Emacs 20.7.1 under Linux (RH7).
;;  Please, let me know if it works with other OS and versions of Emacs.

;;; **************************************************************************
;;; **************************************************************************
;;; **************************************************************************
;;; **************************************************************************
;;; **************************************************************************
;;; Code:

;;; **************************************************************************
;;; ***** customization routines
;;; **************************************************************************
(defgroup joc-java-find nil
  "joc-java-find package customization"
  :group 'tools)

;; ---------------------------------------------------------------------------
(defun joc-java-find-customize ()
  "Customization of the group joc-java-find."
  (interactive)
  (customize-group "joc-java-find"))

;; ---------------------------------------------------------------------------
(defcustom joc-java-find-visit-dirs t
  "Boolean used to determine whether or not to visit directories if
   that's what's found; for example, running joc-java-find-class-at-point
   on an import line such as:

      import com.bar.foo.*;

   will visit the directory only if joc-java-find-visit-dirs is t."
  :group 'joc-java-find
  :type 'boolean)

;; ---------------------------------------------------------------------------
(defcustom joc-java-find-alt-cmd nil
  "An alternate command to run instead of `find-file' when visiting
   source files."
  :group 'joc-java-find
  :type 'function)

;; ---------------------------------------------------------------------------
(defcustom joc-java-find-dired-cmd nil
  "An alternate command to run instead of `find-file' when visiting
   directories (only when joc-java-find-visit-dirs is t)."
  :group 'joc-java-find
  :type 'function)

;;; **************************************************************************
;;; ***** version related routines
;;; **************************************************************************
(defconst joc-java-find-version
  "$Revision: 1.4 $"
  "joc-java-find version number.")

;; ---------------------------------------------------------------------------
(defun joc-java-find-version-number ()
  "Returns joc-java-find version number."
  (string-match "[0123456789.]+" joc-java-find-version)
  (match-string 0 joc-java-find-version))

;; ---------------------------------------------------------------------------
(defun joc-java-find-display-version ()
  "Displays joc-java-find version."
  (interactive)
  (message "joc-java-find version <%s>." (joc-java-find-version-number)))

;;; **************************************************************************
;;; ***** interactive functions
;;; **************************************************************************
(defun joc-java-find-class-at-point ()
  "Finds and visits file or directory associated with classname at point
   (using SOURCEPATH).  See source file for more info."
  (interactive)
  (joc-java-find-visit-class-or-file t))

;; ---------------------------------------------------------------------------
(defun joc-java-find-file-at-point ()
  "Finds and visits file or directory at point (using SOURCEPATH).
   See source file for more info."
  (interactive)
  (joc-java-find-visit-class-or-file nil))

;;; **************************************************************************
;;; ***** non-interactive functions
;;; **************************************************************************
(defun joc-java-find-visit-class-or-file (looking-for-class)
  "workhorse function for java-find.el"
  (save-excursion
	(save-match-data
	  (let ((current) (bol) (eol) (start) (end) (the-name))
		;; save current position
		(setq current (point))

		;; get end of line (for limit)
		(end-of-line)
		(setq eol (point))

		;; get beginning of line (for limit)
		(beginning-of-line)
		(setq bol (point))

		;; search for slightly different stuff depending on what we're
		;; looking for, class or file
;	  (debug)
		(if looking-for-class
			;; we may be on an import line
			(if (re-search-forward "^[ \t]*import" eol t)
				;; it is an import line, so get what's being imported
				(progn
				  (setq start (+ (point) 1))
				  (setq end (- (re-search-forward ";") 1)))

			  ;; we may be on some generic classpath somewhere
			  ;; find beginning of classpath we're on (account for beg-of-line)
			  (goto-char current)
			  (setq start (+ (or (re-search-backward "[^\\.a-z0-9A-Z_]" bol t)
								 (- bol 1)) 1))

			  ;; find end of classpath we're on (account for end-of-line)
			  (goto-char current)
			  (setq end (- (or (re-search-forward "[^\\*\\.a-z0-9A-Z_]" eol t)
							   (+ eol 1)) 1)))

		  ;; we're looking for a file, not a class
		  ;; find beginning of filename we're on (account for beg-of-line)
		  (goto-char current)
;		(debug)
		  (setq start (+ (or (re-search-backward "[^\\.a-z0-9A-Z_/]" bol t)
							 (- bol 1)) 1))

		  ;; find end of classpath we're on (account for end-of-line)
		  (goto-char current)
		  (setq end (- (or (re-search-forward "[^\\.a-z0-9A-Z_/]" eol t)
						   (+ eol 1)) 1)))

		;; do we anything even remotely valid?
		(if (and start end (/= start end))
			(progn
			  ;; parse out classname/filename
			  (setq the-name (buffer-substring start end))

			  ;; strip off possible trailing period
			  (if (string= (substring the-name -1) ".")
				  (setq the-name (substring the-name 0 -1)))

			  ;; do we have something that ends in a star?
			  (if (or (string= (substring the-name -1) "*")
					  (string= (substring the-name -1) "/"))
				  ;; call dired or ignore
				  (if joc-java-find-visit-dirs
					  (progn
						;; get dirname and search for it
						(let* ((dirname (joc-java-classname-to-filename
										 (substring the-name 0 -1) "" looking-for-class))
							   (found (joc-java-find-filename-in-sourcepath dirname)))

						  ;; we found it, so visit it!
						  (if found
							  (funcall (joc-java-find-get-dired-cmd) found)
							(error "Cannot find directory <%s> in SOURCEPATH" dirname))))
					(error "Invalid 'import' -- cannot end in * (see joc-java-find-visit-dirs)"))

				;; try to find file in sourcepath
				(let ((case-fold-search nil)
					  (first-time-thru t)
					  (class-end nil)
					  (found-it nil)
					  (working-name the-name))

				  ;; Try and find the classname/filename somewhere in SOURCEPATH.
				  ;; If it's not found, and we're looking for a classname, strip
				  ;; off the last element in case it's a sub-class.  Keep going as
				  ;; long as there are capital letters in the remaining classname
				  ;; stub (this assumes that the java conventions for package and
				  ;; class naming is followed; just in case, always go thru at
				  ;; least once).	 Stop when done.
				  (while (and (or first-time-thru (string-match "[A-Z]" working-name))
							  (not found-it))
					;; no longer the first time thru
					(setq first-time-thru nil)

					;; do the actual finding
					(let* ((filename (joc-java-classname-to-filename
									  working-name ".java" looking-for-class))
						   (found (joc-java-find-filename-in-sourcepath filename)))
					  ;; if we've found it, set found-it (of course)
					  (if found
						  (setq found-it found)

						;; if no more elements or we're not looking for a classname,
						;;  set to "" so we fail the [A-Z] check above
						(if (not (or looking-for-class
									 (string-match "\\." working-name)))
							(setq working-name "")

						  ;; strip off last element in the hopes that it's a sub-class
						  (string-match "[^\\.]+$" working-name)
						  (setq class-end (- (match-beginning 0) 1))
						  (setq working-name (substring the-name 0 class-end))))))

				  ;; so, did we find anything?
				  (if found-it
					  ;; did we find a file or directory?
					  (if (file-directory-p found-it)
						  ;; found a directory -- just go for it!
						  (funcall (joc-java-find-get-dired-cmd) found-it)

						;; found a file -- check for line num
						(let ((num-start) (num-end) (line-num))
						  ;; look for line number in original line
						  ;; check for (xxx.java:NN) at end of classname
						  (goto-char end)
						  (re-search-forward "([^:]*:\\([0-9]+\\))" eol t)

						  ;; set the start and end to the sub-expression (or eol)
						  (setq num-start (or (match-beginning 1) eol))
						  (setq num-end (or (match-end 1) eol))

						  ;; save the line number here, because after we switch, it's too late
						  (if (/= num-start num-end)
							  (setq line-num (buffer-substring num-start num-end)))

						  (funcall (joc-java-find-get-alt-cmd) found-it)

						  ;; change to the line in question (if we found one)
						  (if (/= num-start num-end)
							  (goto-line (string-to-number line-num)))))
					(error "Cannot find file <%s> in SOURCEPATH" the-name))
				  )))

		  ;; we did NOT have anything even remotely valid
		  (if looking-for-class
			  (error "Point not on valid classname.")
			(error "Point not on valid filename."))
		  )))))

;; ---------------------------------------------------------------------------
(defun joc-java-find-filename-in-sourcepath (filename)
  "Looks for and finds the first matching file (or directory) in SOURCEPATH."
;  (interactive "sFile or directory name: ")
  (let* ((sourcepath (getenv "SOURCEPATH"))
		 (start 0) (end 0) (candidate "")
		 (found nil)
		 (last (length sourcepath)))

	;; loop thru all of the pieces of the sourcepath
	(while (and (not (= start last)) (not found))
	  (setq end (string-match path-separator sourcepath start))
	  (setq candidate (substring sourcepath start end))

	  ;; make sure it ends in (one) slash
	  (if (not (string= (substring candidate -1) "/"))
		  (setq candidate (concat candidate "/")))

	  ;; see if the file exists
	  (if (file-exists-p (concat candidate filename))
		  (setq found (concat candidate filename)))

	  ;; reset start for next iteration
	  (if end
		  ;;  set to end + 1
		  (setq start (match-end 0))

		;;  we're done
		(setq start last)))

	;; if called interactively, visit the file
	(when (and (interactive-p) found)
	  ;; if it's a directory, use dired-cmd
	  (if (file-directory-p found)
		  (funcall (joc-java-find-get-dired-cmd) found)
	  (funcall (joc-java-find-get-alt-cmd) found)))

	;; return the value of found (nil or fname)
	found))

;;; **************************************************************************
;;; ***** utility routines
;;; **************************************************************************
(defun joc-java-find-get-dired-cmd ()
  "Returns the dired command to use, defaults to find-file"
  (let ((rc nil))
	(if (and (boundp 'joc-java-find-dired-cmd) joc-java-find-dired-cmd)
		(setq rc joc-java-find-dired-cmd)
	  (setq rc 'find-file))
	rc))

;; ---------------------------------------------------------------------------
(defun joc-java-find-get-alt-cmd ()
  "Returns the find-file command to use, defaults to find-file"
  (let ((rc nil))
	(if (and (boundp 'joc-java-find-alt-cmd) joc-java-find-alt-cmd)
		(setq rc joc-java-find-alt-cmd)
	  (setq rc 'find-file))
	rc))

;; ---------------------------------------------------------------------------
(defun joc-java-classname-to-filename (classname extension not-no-op)
  "Converts <classname> to a filename (converts '.' to '/' and appends <extension>)."
  ;; this (sadly) uses the looking-for-class as a flag: t means DON'T no-op
  ;; and nil means DO no-op (i.e. do nothing)
  (if not-no-op
	  (while (string-match "\\." classname)
		(setq classname (replace-match "/" nil t classname))))
  (concat classname extension))

;;; **************************************************************************
;;; ***** we're done
;;; **************************************************************************
(provide 'java-find)

;; java-find.el ends here!
;;; **************************************************************************
;;;; *****  EOF  *****  EOF  *****  EOF  *****  EOF  *****  EOF  *************
