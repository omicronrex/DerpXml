#define __DerpXml_Init
/// DerpXml_Init()
//
//  Initializes DerpXml. Call this once at the start of your game.

object_event_add(gm82core_object,ev_create,0,"
    readMode_String = 0
    readMode_File = 1
    attributeMap = ds_map_create()

    readMode = readMode_String
    xmlString = ''
    xmlFile = -1

    stringPos = 0
    currentType = DerpXmlType_StartOfFile
    currentValue = ''
    currentRawValue = ''
    lastReadEmptyElement = false
    lastNonCommentType = DerpXmlType_StartOfFile

    indentString = '  '
    newlineString = chr(10)
    tagNameStack = ds_stack_create()

    writeString = ''
    currentIndent = 0
    lastWriteType = DerpXmlType_StartOfFile
    lastWriteEmptyElement = false
")


#define DerpXmlRead_OpenFile
/// DerpXmlRead_OpenFile(xmlFilePath)
//
//  Opens an XML file for reading. Be sure to call DerpXmlRead_CloseFile when you're done.
//  Returns whether load was successful.

var xmlFilePath;xmlFilePath = argument0

var file;file = file_text_open_read(xmlFilePath)
if file == -1 {
    return false
}
with gm82core_object {
    xmlFile = file
    readMode = readMode_File
    xmlString = file_text_read_string(xmlFile)
    
    stringPos = 0
    currentType = DerpXmlType_StartOfFile
    currentValue = ''
    currentRawValue = ''
    lastReadEmptyElement = false
}

return true

#define DerpXmlRead_CloseFile
/// DerpXmlRead_CloseFile()
//
//  Closes the currently open XML file.

file_text_close(gm82core_object.xmlFile)

#define DerpXmlRead_LoadString
/// DerpXmlRead_LoadFromString(xmlString)
//
//  Loads XML contained in a string. e.g. "<a>derp</a>"

var xmlString;xmlString = argument0

with gm82core_object {
    self.xmlString = xmlString
    readMode = readMode_String
    
    stringPos = 0
    currentType = DerpXmlType_StartOfFile
    currentValue = ''
    currentRawValue = ''
    lastReadEmptyElement = false
}

#define DerpXmlRead_UnloadString
/// DerpXmlRead_UnloadString()
//
//  Empties the input xml string (if reading from string) so its memory can be freed later.

gm82core_object.xmlString = ''

#define DerpXmlRead_Read
/// DerpXmlRead_Read()
//
//  Reads the next XML node. (tag, text, etc.)
//
//  Returns true if the next node was read successfully, 
//  and false if there are no more nodes to read.

with gm82core_object {
    var readString;readString = ''
    var numCharsRead;numCharsRead = 0
    if currentType != DerpXmlType_Comment {
        lastNonCommentType = currentType
    }
    
    var isTag;isTag = false
    var isClosingTag;isClosingTag = false
    var isEmptyElement;isEmptyElement = false
    var tagState;tagState = ''
    var tagName;tagName = ''
    var attrKey;attrKey = ''
    var attrVal;attrVal = ''
    ds_map_clear(attributeMap)
    var isComment;isComment = false
    
    // if was already at end of file, just return false
    if currentType == DerpXmlType_EndOfFile {
        return false
    }
    
    // if last read was empty element, just return a closing tag this round
    if lastReadEmptyElement {
        lastReadEmptyElement = false
        currentType = DerpXmlType_CloseTag
        // don't change currentValue to keep it same as last read
        currentRawValue = ''
        return true
    }
    
    // main read loop
    while true {
        // advance in the document
        stringPos += 1
        
        // file detect end of line (and possibly end of document)
        if readMode == readMode_File and stringPos > string_length(xmlString) {
            file_text_readln(xmlFile)
            if file_text_eof(xmlFile) {
                currentType = DerpXmlType_EndOfFile
                currentValue = ''
                currentRawValue = ''
                return false
            }
            xmlString = file_text_read_string(xmlFile)
            stringPos = 1
        }
        
        // string detect end of document
        if readMode == readMode_String and stringPos > string_length(xmlString) {
            stringPos = string_length(xmlString)
            currentType = DerpXmlType_EndOfFile
            currentValue = ''
            currentRawValue = ''
            return false
        }
        
        // grab the new character
        var currentChar;currentChar = string_char_at(xmlString, stringPos);
        readString += currentChar
        numCharsRead += 1
        
        // main state 1: in the middle of parsing a tag
        if isTag {
            // reach > and not in attribute value, so end of tag
            if currentChar == '>' and tagState != 'attr_value' {
                // if comment, check for "--" before
                if isComment {
                    if string_copy(readString, string_length(readString)-2, 2) == '--' {
                        currentType = DerpXmlType_Comment
                        currentValue = string_copy(readString, 5, string_length(readString)-7)
                        currentRawValue = readString
                        return true
                    }
                }
                // if not comment, then do either closing or opening tag behavior
                else {
                    if isClosingTag {
                        currentType = DerpXmlType_CloseTag
                        currentValue = tagName
                        currentRawValue = readString
                        return true
                    }
                    else {
                        // if empty element, set the flag for the next read
                        if isEmptyElement {
                            lastReadEmptyElement = true
                        }
                        
                        currentType = DerpXmlType_OpenTag
                        currentValue = tagName
                        currentRawValue = readString
                        return true
                }
                }
            }
            
            // not end of tag, so either tag name or some attribute state
            if tagState == 'tag_name' {
                // check if encountering space, so done with tag name
                if currentChar == ' ' {
                    tagState = 'whitespace'
                }
                
                // check for beginning slash
                else if currentChar == '/' and numCharsRead == 2 {
                    isClosingTag = true
                }
                
                // check for ending slash
                else if currentChar == '/' and numCharsRead > 2 {
                    isEmptyElement = true
                }
                
                // in the normal case, just add to tag name
                else {
                    tagName += currentChar
                }
                
                // check if tag "name" means it's a comment
                if tagName == '!--' {
                    isComment = true
                }
            }
            else if tagState == 'whitespace' {
                // check for ending slash
                if currentChar == '/' {
                    isEmptyElement = true
                }
                // if encounter non-space and non-slash character, it's the start of a key
                else if currentChar != ' ' {
                    attrKey += currentChar
                    tagState = 'key'
                }
            }
            else if tagState == 'key' {
                // if encounter = or space, start the value whitespace
                if currentChar == '=' or currentChar == ' ' {
                    tagState = 'value_whitespace'
                }
                
                // in the normal case, just add to the key
                else {
                    attrKey += currentChar
                }
            }
            else if tagState == 'value_whitespace' {
                // if encounter quote, start the key
                if currentChar == '"' or currentChar == "'" {
                    tagState = 'value'
                }
            }
            else if tagState == 'value' {
                // if encounter quote, we're done with the value, store the attribute and return to whitespace
                if currentChar == '"' or currentChar == "'" {
                    ds_map_set(attributeMap,attrKey,attrVal)
                    attrKey = ''
                    attrVal = ''
                    tagState = 'whitespace'
                }
                else {
                    attrVal += currentChar
                }
            }
        }
        
        // main state 2: not parsing a tag
        else {
            // first character is <, so we're starting a tag
            if currentChar == '<' and numCharsRead == 1 {
                isTag = true
                tagState = 'tag_name'
            }
            
            // reach a < that's not the first character, which is the end of text and whitespace
            if currentChar == '<' and numCharsRead > 1 {
                if string_char_at(xmlString, stringPos+1) == '/' and lastNonCommentType == DerpXmlType_OpenTag {
                    currentType = DerpXmlType_Text
                }
                else {
                    currentType = DerpXmlType_Whitespace
                }
                stringPos -= 1
                currentValue = string_copy(readString, 1, string_length(readString)-1)
                currentRawValue = currentValue
                return true
            }
        }
    }
}

#define DerpXmlRead_CurType
/// DerpXmlRead_CurType()
//
//  Returns the type of the current node, as a DerpXmlType macro.
//
//  DerpXmlType_OpenTag     - Opening tag <tag>
//  DerpXmlType_CloseTag    - Closing tag </tag>
//  DerpXmlType_Text        - Text inside an element <a>TEXT</a>
//  DerpXmlType_Whitespace  - Whitespace between elements "    "
//  DerpXmlType_StartOfFile - Start of document, no reads performed yet
//  DerpXmlType_EndOfFile   - End of document

return gm82core_object.currentType

#define DerpXmlRead_CurValue
/// DerpXmlRead_CurValue()
//
//  Returns the content value of the current node.
//
//  DerpXmlType_Open/CloseTag <tagname> - tagname
//  DerpXmlType_Text <a>text</a>        - text
//  DerpXmlType_Whitespace "    "       - "    "

return gm82core_object.currentValue

#define DerpXmlRead_CurRawValue
/// DerpXmlRead_CurRawValue()
//
//  Returns the raw text that was last read, with nothing stripped out.
//  For example: "<tagname key1="val1">"

return gm82core_object.currentRawValue

#define DerpXmlRead_CurGetAttribute
/// DerpXmlRead_CurGetAttribute(keyString)
//
//  Returns the value for the given key in the current node's attributes.
//  Example: in <a cat="bag>     DXR_CGA('cat') returns 'bag'
//
//  If the attribute doesn't exist, calling is_undefined() on the return value will return true.
//  See the example scripts, DerpXmlExample_ReadOther for usage.

var keyString;keyString = argument0

if (!ds_map_exists(gm82core_object.attributeMap,keyString)) return undefined
return ds_map_find_value(gm82core_object.attributeMap,keyString)

#define DerpXmlWrite_New
/// DerpXmlWrite_New(filePath)
//
//  Starts a new empty xml string.

with gm82core_object {
    writeString = ''
    currentIndent = 0
    lastWriteType = DerpXmlType_StartOfFile
    lastWriteEmptyElement = false
}

#define DerpXmlWrite_Config
/// DerpXmlWrite_Config(indentString, newlineString)
//
//  Configures options for writing.
//
//  indentString     String used for indents, default is "  ". Set to "" to disable indents.
//  newlineString    String used for newlines, default is chr(10). Set to "" to disable newlines.

var indentString;indentString = argument0
var newlineString;newlineString = argument1

with gm82core_object {
    self.indentString = indentString
    self.newlineString = newlineString
}

#define DerpXmlWrite_GetString
/// DerpXmlWrite_GetString()
//
//  Returns the built xml string.

return gm82core_object.writeString

#define DerpXmlWrite_UnloadString
/// DerpXmlWrite_UnloadString()
//
//  Empties the current built xml string so its memory can be freed later.

gm82core_object.writeString = ''

#define DerpXmlWrite_OpenTag
/// DerpXmlWrite_OpenTag(tagName)
//
//  Writes an open tag, e.g. <tagName>

var tagName;tagName = argument0;

with gm82core_object {
    if lastWriteType == DerpXmlType_OpenTag {
        currentIndent += 1
    }
    
    writeString += newlineString
    repeat currentIndent {
        writeString += indentString
    }
    
    writeString += '<'+tagName+'>'
    lastWriteType = DerpXmlType_OpenTag
    ds_stack_push(tagNameStack, tagName)
    lastWriteEmptyElement = false
}

#define DerpXmlWrite_CloseTag
/// DerpXmlWrite_CloseTag()
//
//  Writes a close tag, e.g. </tagname>. DerpXml remembers the name that matches it.

with gm82core_object {
    if lastWriteType == DerpXmlType_CloseTag {
        writeString += newlineString
        currentIndent -= 1
        repeat currentIndent {
            writeString += indentString
        }
    }
    
    var value;
    if ds_stack_size(tagNameStack) > 0 {
        value = ds_stack_pop(tagNameStack)
    }
    else {
        DerpXml_ThrowError("There was no opening tag to this closing tag!")
    }
    writeString += '</'+value+'>'
    lastWriteType = DerpXmlType_CloseTag
    lastWriteEmptyElement = false
}

#define DerpXmlWrite_Text
/// DerpXmlWrite_Text(text)
//
//  Writes text for the middle of an element.

var text;text = argument0;

with gm82core_object {
    writeString += text
    lastWriteType = DerpXmlType_Text
    lastWriteEmptyElement = false
}

#define DerpXmlWrite_Attribute
/// DerpXmlWrite_Attribute(key, value)
//
//  Adds an attribute to the open tag that was just written.
//  Call this right after DerpXmlWrite_OpenTag, or DerpXmlWrite_LeafElement with no text.
//
//  <newTag>    -->    <newTag key="value">

var key;key = argument0
var value;value = argument1

with gm82core_object {
    // verify the last added thing was an open tag or empty element
    if lastWriteType != DerpXmlType_OpenTag and not lastWriteEmptyElement {
        DerpXml_ThrowError("Attributes was added directly after something that wasn't an open tag, empty element, or another attribute!");
    }

    // find appropriate place to insert. one character back if an empty element.
    var insertPos;insertPos = string_length(writeString)
    if lastWriteEmptyElement {
        insertPos -= 1
    }
    
    var insertString;insertString = ' ' + string(key) + '="' + string(value) + '"'
    writeString = string_insert(insertString, writeString, insertPos)
}

#define DerpXmlWrite_LeafElement
/// DerpXMlWrite_LeafElement(tagName, text)
//
//  Writes an element with no children, e.g. <tagName>text</tagName>
//  If you supply '' as text, the empty element syntax will be used, e.g. <tagName/>

var tagName;tagName = argument0
var text;text = argument1

if text != '' {
    DerpXmlWrite_OpenTag(tagName)
    DerpXmlWrite_Text(text)
    DerpXmlWrite_CloseTag()
}
else {
    with gm82core_object {
        if lastWriteType == DerpXmlType_OpenTag {
            currentIndent += 1
        }
        
        writeString += newlineString
        repeat currentIndent {
            writeString += indentString
        }
        
        writeString += '<'+tagName+'/>'
        lastWriteType = DerpXmlType_CloseTag
        lastWriteEmptyElement = true
    }
}

#define DerpXmlWrite_Comment
/// DerpXmlWrite_Comment(commentText)
//
//  Writes a comment element on a new line, e.g. <!--commentText-->

var commentText;commentText = argument0

with gm82core_object {
    if lastWriteType == DerpXmlType_CloseTag {
        writeString += newlineString
        repeat currentIndent {
            writeString += indentString
        }
    }
    
    writeString += '<!--'+commentText+'-->'
    lastWriteEmptyElement = false
}


#define DerpXml_ThrowError
/// DerpXml_CauseError(message)
//
//  Causes a runtime error with a certain message.
//  This script is used internally in DerpXml; you shouldn't call it yourself.

var message;message = argument0

message = 'DerpXml Error: ' + message
show_debug_message(message)
var a;a = 0;
a += 'DerpXml Error. See the console output for details.'

