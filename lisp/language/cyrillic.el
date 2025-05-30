;;; cyrillic.el --- support for Cyrillic -*- coding: utf-8; lexical-binding: t; -*-

;; Copyright (C) 1997-1998, 2001-2025 Free Software Foundation, Inc.
;; Copyright (C) 1995, 1996, 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004,
;;   2005, 2006, 2007, 2008, 2009, 2010, 2011
;;   National Institute of Advanced Industrial Science and Technology (AIST)
;;   Registration Number H14PRO021
;; Copyright (C) 2003
;;   National Institute of Advanced Industrial Science and Technology (AIST)
;;   Registration Number H13PRO009

;; Author: Kenichi Handa <handa@gnu.org>
;; Keywords: multilingual, Cyrillic, i18n

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; The character set ISO8859-5 is supported.  KOI-8 and ALTERNATIVNYJ
;; are converted to Unicode internally.  See
;; <URL:http://www.ecma.ch/ecma1/STAND/ECMA-113.HTM>.  For more info
;; on Cyrillic charsets, see
;; <URL:https://czyborra.com/charsets/cyrillic.html>.

;; Note that 8859-5 maps directly onto the Unicode Cyrillic block,
;; apart from codepoints 160 (NBSP, cf. U+0400), 173 (soft hyphen,
;; cf. U+04OD) and 253 (section sign, cf. U+045D).  The KOI-8 and
;; Alternativnyj coding systems encode both 8859-5 and Unicode.

;;; Code:

;; Cyrillic (general)

;; ISO-8859-5 stuff

(define-coding-system 'cyrillic-iso-8bit
  "ISO 2022 based 8-bit encoding for Cyrillic script (MIME:ISO-8859-5)."
  :coding-type 'charset
  :mnemonic ?5
  :charset-list '(iso-8859-5)
  :mime-charset 'iso-8859-5)

(define-coding-system-alias 'iso-8859-5 'cyrillic-iso-8bit)

(set-language-info-alist
 "Cyrillic-ISO" '((charset iso-8859-5)
		  (coding-system cyrillic-iso-8bit)
		  (coding-priority cyrillic-iso-8bit)
		  (input-method . "cyrillic-yawerty") ; fixme
		  (nonascii-translation . iso-8859-5)
		  (unibyte-display . cyrillic-iso-8bit)
		  (features cyril-util)
		  (sample-text . "Russian (Русский)	Здравствуйте!")
		  (documentation . "Support for Cyrillic ISO-8859-5."))
 '("Cyrillic"))

;; KOI-8R stuff

(define-coding-system 'cyrillic-koi8
  "KOI8 8-bit encoding for Cyrillic (MIME: KOI8-R)."
  :coding-type 'charset
  ;; We used to use ?K.  It is true that ?K is more strictly correct,
  ;; but it is also used for Korean.  So people who use koi8 for
  ;; languages other than Russian will have to forgive us.
  :mnemonic ?R
  :charset-list '(koi8)
  :mime-charset 'koi8-r)

(define-coding-system-alias 'koi8-r 'cyrillic-koi8)
(define-coding-system-alias 'koi8 'cyrillic-koi8)
(define-coding-system-alias 'cp878 'cyrillic-koi8)

(set-language-info-alist
 "Cyrillic-KOI8" '((charset koi8)
		   (coding-system cyrillic-koi8)
		   (coding-priority cyrillic-koi8 cyrillic-iso-8bit)
		   (ctext-non-standard-encodings "koi8-r")
		   (nonascii-translation . koi8)
		   (input-method . "russian-typewriter")
		   (features cyril-util)
		   (unibyte-display . cyrillic-koi8)
		   (sample-text . "Russian (Русский)	Здравствуйте!")
		   (documentation . "Support for Cyrillic KOI8-R."))
 '("Cyrillic"))

(set-language-info-alist
 "Russian" `((charset cyrillic-iso8859-5)
	     (nonascii-translation
	      . ,(get 'cyrillic-koi8-r-nonascii-translation-table
		      'translation-table))
	     (coding-system cyrillic-koi8)
	     (coding-priority cyrillic-koi8 cyrillic-iso-8bit)
	     (input-method . "russian-computer")
	     (features cyril-util)
	     (unibyte-display . cyrillic-koi8)
	     (sample-text . "Russian (Русский)	Здравствуйте!")
	     (documentation . "\
Support for Russian using koi8-r and the russian-computer input method.")
	     (tutorial . "TUTORIAL.ru"))
 '("Cyrillic"))

(define-coding-system 'koi8-u
  "KOI8-U 8-bit encoding for Cyrillic (MIME: KOI8-U)"
  :coding-type 'charset
  ;; This used to be ?U which collided with UTF-8.
  :mnemonic ?У                          ; CYRILLIC CAPITAL LETTER U
  :charset-list '(koi8-u)
  :mime-charset 'koi8-u)

(set-language-info-alist
 "Ukrainian" '((tutorial . "TUTORIAL.uk")
	       (charset koi8-u)
	       (coding-system koi8-u)
	       (coding-priority koi8-u)
	       (nonascii-translation . koi8-u)
	       (input-method . "ukrainian-computer")
	       (sample-text . "Ukrainian (Українська)	Вітаю / Добрий день! / Привіт")
	       (documentation
		. "Support for Ukrainian with koi8-u character set."))
 '("Cyrillic"))

;;; ALTERNATIVNYJ stuff

(define-coding-system 'cyrillic-alternativnyj
  "ALTERNATIVNYJ 8-bit encoding for Cyrillic."
  :coding-type 'charset
  :mnemonic ?A
  :charset-list '(alternativnyj))

(define-coding-system-alias 'alternativnyj 'cyrillic-alternativnyj)

(set-language-info-alist
 "Cyrillic-ALT" '((charset alternativnyj)
		  (coding-system cyrillic-alternativnyj)
		  (coding-priority cyrillic-alternativnyj)
		  (nonascii-translation . alternativnyj)
		  (input-method . "russian-typewriter")
		  (features cyril-util)
		  (unibyte-display . cyrillic-alternativnyj)
		  (sample-text . "Russian (Русский)	Здравствуйте!")
		  (documentation . "Support for Cyrillic ALTERNATIVNYJ."))
 '("Cyrillic"))

(define-coding-system 'cp866
  "CP866 encoding for Cyrillic."
  :coding-type 'charset
  :mnemonic ?*
  :charset-list '(ibm866)
  :mime-charset 'cp866)

(define-coding-system 'koi8-t
  "KOI8-T 8-bit encoding for Cyrillic"
  :coding-type 'charset
  :mnemonic ?*
  :charset-list '(koi8-t)
  :mime-charset 'koi8-t)

(define-coding-system 'windows-1251
  "windows-1251 8-bit encoding for Cyrillic (MIME: WINDOWS-1251)"
  :coding-type 'charset
  :mnemonic ?b
  :charset-list '(windows-1251)
  :mime-charset 'windows-1251)
(define-coding-system-alias 'cp1251 'windows-1251)

(define-coding-system 'cp1125
  "cp1125 8-bit encoding for Cyrillic"
  :coding-type 'charset
  :mnemonic ?*
  :charset-list '(cp1125))
(define-coding-system-alias 'ruscii 'cp1125)
;; Original name for cp1125, says Serhii Hlodin <hlodin@lutsk.bank.gov.ua>
(define-coding-system-alias 'cp866u 'cp1125)

(define-coding-system 'cp855
  "DOS codepage 855 (Russian)"
  :coding-type 'charset
  :mnemonic ?D
  :charset-list '(cp855)
  :mime-charset 'cp855)
(define-coding-system-alias 'ibm855 'cp855)

(define-coding-system 'mik
  "Bulgarian DOS codepage"
  :coding-type 'charset
  :mnemonic ?D
  :charset-list '(mik))

(define-coding-system 'pt154
  "ParaType Asian Cyrillic codepage"
  :coding-type 'charset
  :mnemonic ?D
  :charset-list '(pt154))

;; (set-language-info-alist
;;  "Windows-1251" `((coding-system windows-1251)
;; 		  (coding-priority windows-1251)
;; 		  (input-method . "russian-typewriter") ; fixme?
;; 		  (features code-pages)
;; 		  (documentation . "Support for windows-1251 character set."))
;;  '("Cyrillic"))

(set-language-info-alist
 "Tajik" '((coding-system koi8-t)
	   (coding-priority koi8-t)
	   (nonascii-translation . cyrillic-koi8-t)
	   (charset koi8-t)
	   (input-method . "russian-typewriter") ; fixme?
	   (features code-pages)
	   (documentation . "Support for Tajik using KOI8-T."))
 '("Cyrillic"))

(set-language-info-alist
 "Bulgarian" '((coding-system windows-1251)
	       (coding-priority windows-1251)
	       (nonascii-translation . windows-1251)
	       (charset windows-1251)
	       (ctext-non-standard-encodings "microsoft-cp1251")
	       (input-method . "bulgarian-bds")
	       (documentation
		. "Support for Bulgarian with windows-1251 character set."))
 '("Cyrillic"))

(set-language-info-alist
 "Belarusian" '((coding-system windows-1251)
		(coding-priority windows-1251)
		(nonascii-translation . windows-1251)
		(charset windows-1251)
		(ctext-non-standard-encodings "microsoft-cp1251")
		(input-method . "belarusian")
		(documentation
		 . "Support for Belarusian with windows-1251 character set.
\(The name Belarusian replaced Byelorussian in the early 1990s.)"))
 '("Cyrillic"))

;; The Mongolian-traditional language environment is in misc-lang.el.
(set-language-info-alist
 "Mongolian-cyrillic" '((coding-system utf-8)
	                (coding-priority utf-8)
	                (input-method . "cyrillic-mongolian")
		        (sample-text . "Mongolian (монгол хэл)	Сайн байна уу?")
	                (documentation
		         . "Support for Mongolian language with Cyrillic alphabet."))
 '("Cyrillic"))

(provide 'cyrillic)

;;; cyrillic.el ends here
