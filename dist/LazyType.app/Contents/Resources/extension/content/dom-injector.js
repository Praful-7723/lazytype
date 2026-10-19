/**
 * DOM Input Injection Utilities for Modern Reactive Frameworks
 * Safely inserts text into React, Vue, Angular, Svelte, and ContentEditable inputs.
 */

if (!window.LazyTypeInjector) {
  window.LazyTypeInjector = {
    /**
     * Resiliently insert text into an HTML input, textarea, or contenteditable element.
     * Dispatches proper InputEvents and triggers framework listeners.
     */
    insertText(element, text) {
      if (!element) {
        throw new Error('INPUT_NOT_FOUND');
      }

      element.focus();

      if (element.tagName === 'TEXTAREA' || element.tagName === 'INPUT') {
        // Reset React 15/16/17/18 internal value tracker so onChange/onInput always fires
        if (element._valueTracker) {
          element._valueTracker.setValue('');
        }

        // Use native prototype setter to bypass React 16+ synthetic event wrapper
        const prototype = element.tagName === 'TEXTAREA'
          ? window.HTMLTextAreaElement.prototype
          : window.HTMLInputElement.prototype;
        
        const descriptor = Object.getOwnPropertyDescriptor(prototype, 'value');
        if (descriptor && descriptor.set) {
          descriptor.set.call(element, text);
        } else {
          element.value = text;
        }

        // Dispatch beforeinput
        try {
          const beforeInputEvent = new InputEvent('beforeinput', {
            bubbles: true,
            cancelable: true,
            inputType: 'insertText',
            data: text
          });
          element.dispatchEvent(beforeInputEvent);
        } catch (e) {
          const evt = document.createEvent('Event');
          evt.initEvent('beforeinput', true, true);
          element.dispatchEvent(evt);
        }

        // Dispatch input event
        try {
          const inputEvent = new InputEvent('input', {
            bubbles: true,
            cancelable: true,
            inputType: 'insertText',
            data: text
          });
          element.dispatchEvent(inputEvent);
        } catch (e) {
          element.dispatchEvent(new Event('input', { bubbles: true }));
        }

        // Dispatch change event
        element.dispatchEvent(new Event('change', { bubbles: true }));

        // Dispatch subtle key events to trigger framework typing listeners
        element.dispatchEvent(new KeyboardEvent('keydown', { key: 'Unidentified', bubbles: true }));
        element.dispatchEvent(new KeyboardEvent('keyup', { key: 'Unidentified', bubbles: true }));

      } else if (element.isContentEditable || element.getAttribute('contenteditable') === 'true' || element.getAttribute('role') === 'textbox') {
        // ContentEditable elements (Slack, Teams, Modern Zoom Web, Discord, TipTap, Lexical)
        element.focus();
        
        // Select all existing content before inserting to replace completely
        try {
          const sel = window.getSelection();
          if (sel) {
            const range = document.createRange();
            range.selectNodeContents(element);
            sel.removeAllRanges();
            sel.addRange(range);
          }
        } catch (e) {}

        // Try document.execCommand('insertText') first for maximum framework compatibility
        const execSuccess = document.execCommand('insertText', false, text);
        if (!execSuccess || element.innerText !== text) {
          element.innerText = text;
          element.dispatchEvent(new InputEvent('beforeinput', { bubbles: true, cancelable: true, inputType: 'insertText', data: text }));
          element.dispatchEvent(new InputEvent('input', { bubbles: true, cancelable: true, inputType: 'insertText', data: text }));
          element.dispatchEvent(new Event('change', { bubbles: true }));
        }
      } else {
        element.textContent = text;
        element.dispatchEvent(new Event('input', { bubbles: true }));
        element.dispatchEvent(new Event('change', { bubbles: true }));
      }
    },

    /**
     * Dispatch full Enter key event lifecycle (keydown, keypress, keyup)
     */
    dispatchEnter(element) {
      if (!element) return false;
      element.focus();

      const keyboardInit = {
        key: 'Enter',
        code: 'Enter',
        keyCode: 13,
        which: 13,
        charCode: 13,
        bubbles: true,
        cancelable: true,
        view: window
      };

      const downEvent = new KeyboardEvent('keydown', keyboardInit);
      const pressEvent = new KeyboardEvent('keypress', keyboardInit);
      const upEvent = new KeyboardEvent('keyup', keyboardInit);

      const downAllowed = element.dispatchEvent(downEvent);
      element.dispatchEvent(pressEvent);
      element.dispatchEvent(upEvent);

      return downAllowed;
    },

    /**
     * Dispatch single key event
     */
    dispatchKey(element, keyName, modifiers = {}) {
      const target = element || document.activeElement || document.body;
      target.focus();

      let keyCode = 0;
      if (keyName === 'Enter') keyCode = 13;
      else if (keyName === 'Backspace') keyCode = 8;
      else if (keyName === 'Tab') keyCode = 9;
      else if (keyName === 'Escape') keyCode = 27;
      else if (keyName === 'Space') keyCode = 32;
      else if (keyName === 'ArrowUp') keyCode = 38;
      else if (keyName === 'ArrowDown') keyCode = 40;
      else if (keyName === 'ArrowLeft') keyCode = 37;
      else if (keyName === 'ArrowRight') keyCode = 39;

      const eventInit = {
        key: keyName,
        code: keyName,
        keyCode: keyCode,
        which: keyCode,
        bubbles: true,
        cancelable: true,
        metaKey: modifiers.cmd || false,
        shiftKey: modifiers.shift || false,
        altKey: modifiers.alt || false,
        ctrlKey: modifiers.ctrl || false,
        view: window
      };

      target.dispatchEvent(new KeyboardEvent('keydown', eventInit));
      target.dispatchEvent(new KeyboardEvent('keyup', eventInit));
    },

    /**
     * Resiliently click an element across modern UI frameworks (Pointer + Mouse + Click)
     */
    safeClick(element) {
      if (!element) return false;
      element.focus();
      
      const evtInit = { bubbles: true, cancelable: true, view: window };
      try {
        element.dispatchEvent(new PointerEvent('pointerdown', evtInit));
      } catch (e) {}
      element.dispatchEvent(new MouseEvent('mousedown', evtInit));
      try {
        element.dispatchEvent(new PointerEvent('pointerup', evtInit));
      } catch (e) {}
      element.dispatchEvent(new MouseEvent('mouseup', evtInit));
      element.click();
      return true;
    }
  };
}
