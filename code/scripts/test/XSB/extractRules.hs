module Main where

import Text.ParserCombinators.Parsec
import qualified Text.ParserCombinators.Parsec.Token as P
import Text.ParserCombinators.Parsec.Language
import Text.ParserCombinators.Parsec.Expr
import Text.ParserCombinators.Parsec.Perm
import Char
-- Esta parte (variando pequeñas cosas) es igual para todos los ficheros con Parsec

prologStyle :: LanguageDef st
prologStyle= emptyDef
                { commentStart = "/*"
                , commentEnd = "*/"
                , commentLine = "###"
                , nestedComments = True
                , identStart = letter
                , identLetter   = alphaNum <|> oneOf "_'"
-- , opStart   = opLetter prologStyle
-- , opLetter   = oneOf ":!#$%&*+./<=>?@\\^|-~"
                , reservedOpNames= []
                , reservedNames = []
                , caseSensitive = True
                }

lexer :: P.TokenParser ()
lexer = P.makeTokenParser prologDef

prologDef = prologStyle
            { reservedOpNames = [":-","|","!"]
            }

-- Se saca fuera de la clase por optimalidad (según el manual)

whiteSpace = P.whiteSpace lexer
lexeme     = P.lexeme lexer
symbol     = P.symbol lexer
natural    = P.natural lexer
parens     = P.parens lexer
semi       = P.semi lexer
comma      = P.comma lexer
colon      = P.colon lexer
identifier = P.identifier lexer
reserved   = P.reserved lexer
reservedOp = P.reservedOp lexer
dot        = P.dot lexer
integer    = P.integer
stringLiteral    = P.stringLiteral

runLex :: Show a => Parser a -> String -> IO ()
runLex p input
        = run (do{ whiteSpace 
                 ; x <- p
                 ; eof
                 ; return x
                 }) input

run :: Show a => Parser a -> String -> IO ()
run p input
        = case (parse p "" input) of
            Left err -> do{ putStr "parse error at "
                          ; print err
                          }
            Right x -> print x



----------------------------------------------------------------------------
----------------------------------------------------------------------------
--------------------Funciones relacionadas con la E/S-----------------------
----------------------------------------------------------------------------
----------------------------------------------------------------------------

 -- Módulo que divide las lineas de entrada en tres grupos y elimina las lineas innecesarias
splitUpInput :: [String] -> Int -> [[String]]

splitUpInput [] part = [[],[],[]]                   -- [[domain lines],[relations lines],[rules lines]]
splitUpInput ("":xs) part = splitUpInput xs part -- Si es una linea en blanco simplemente se omite
splitUpInput (x:xs) part
    | head x /= '#' = addLine (splitUpInput xs part) x part
    | (x == "### Domains") = splitUpInput xs 1 -- La linea se omite y las que habrá debajo de ella pertenecerán a la parte de los dominios
    | (x == "### Relations") = splitUpInput xs 2 -- La linea se omite y las que habrá debajo de ella pertenecerán a la parte de las relaciones
    | (x == "### Rules") = splitUpInput xs 3 -- La linea se omite y las que habrá debajo de ella pertenecerán a la parte de las reglas
    | otherwise = splitUpInput xs part -- El caso final son los comentarios que no tienen que ver con los anteriores.

-- Módulo que añade la linea dada al grupo que debería pertenecer
addLine :: [[String]] -> String -> Int -> [[String]]
addLine (dom:rel:rul:rest) line 1 = ((line:dom):rel:rul:rest)
addLine (dom:rel:rul:rest) line 2 = (dom:(line:rel):rul:rest)
addLine (dom:rel:rul:rest) line 3 = (dom:rel:(line:rul):rest)

----------------------------------------------------------------------------
----------------------------------------------------------------------------
-------------------------Funciones para los dominios------------------------
----------------------------------------------------------------------------
----------------------------------------------------------------------------

-- Módulo que le pasa a run cada una de las lineas correspondientes a los dominios
domains (x:[]) = run domain x
domains (x:xs) = do
                run domain x
                domains xs

-- Módulo que parsea los dominios.
domain = do{ whiteSpace
            ; domain_id <- identifier <?> "111"
            ; num <- many1 digit -- puede que en el main se haya convertido a int
            ; whiteSpace
            ; filename <- identifier <?> "222"
            ; dot
            ; ext <- identifier <?> "333"
            ; return (domain_id:(numToString num):(filename++"."++ext):[])
            }
        where
            numToString num = show(merge 1 (reverse (map digitToInt num)))
            merge fact [] = 0
            merge fact (x:xs) = (merge (10*fact) xs) + x*fact




----------------------------------------------------------------------------
----------------------------------------------------------------------------
------------------------Funciones para las relaciones-----------------------
----------------------------------------------------------------------------
----------------------------------------------------------------------------

-- Módulo que le pasa a run cada una de las lineas correspondientes a las relaciones
relations (x:[]) = run relation x
relations (x:xs) = do
                run relation x
                relations xs

-- Módulo que parsea 'relation'
relation :: Parser [[String]]
relation = do{
            ; identif <- identifier
            ; p_list <- parens parameter_list--parameter_list
            ; io_nature <- identifier
            ; return ([identif]:p_list:[io_nature]:[])
            }

-- Módulo que parsea 'parameter_list'
parameter_list :: Parser [String]
parameter_list = do{
            ; identif1 <- identifier
            ; colon
            ; identif2 <- identifier
            ; p_tail <- parameter_tail
            ; return (identif1:identif2:p_tail)
            }

-- Módulo que parsea 'parameter_tail'
parameter_tail :: Parser [String]
parameter_tail = do{
                ; comma
                ; p_list <- parameter_list
                ;return (",":p_list)
                }
            <|> do{
                ; whiteSpace
                ; return []
            }

----------------------------------------------------------------------------
----------------------------------------------------------------------------
------------------------Funciones para las reglas---------------------------
----------------------------------------------------------------------------
----------------------------------------------------------------------------

rules (x:[]) = run clause x
rules (x:xs) = do
                run clause x
                rules xs

clause :: Parser [[[[String]]]]
clause = do{
        ; c_atom <- clause_atom  -- devuelve [[String]]
        ; c_tail <- clause_tail  -- devuelve [[[String]]]
        ; dot
        ; return ([c_atom]:(init c_tail):[]) -- init c_tail para eliminar la lista vacía sobrante al final
        }

clause_atom :: Parser [[String]]
clause_atom = do{
        ; id <- identifier
        ; p_list <- parenthesized_list
        ; return ([id]:p_list:[])
        }

parenthesized_list :: Parser [String]
parenthesized_list = do{
        ; arg_list <- parens argument_list
        ; return arg_list
        }

argument_list :: Parser [String]
argument_list = do{
        ; term <- identifier
        ; arg_tail <- argument_tail
        ; return (term:arg_tail)
        }

argument_tail :: Parser [String]
argument_tail = do{
                ; comma
                ; arg_list <- argument_list
                ;return arg_list
                }
            <|> do{
                ; whiteSpace
                ; return []
            }

clause_tail :: Parser [[[String]]]
clause_tail = do{
            ; symbol ":-"
            ; lit_list <- literal_list
            ; return lit_list
            }
        <|>
              do{
            ; whiteSpace
            ; return [[[]]]
            } 

literal_list :: Parser [[[String]]]
literal_list = do{
        ; lit <- literal
        ; l_tail <- literal_tail
        ; return (lit:l_tail)
        }

literal :: Parser [[String]]
literal = do{
        ; identif <- identifier
        ; p_list <- parenthesized_list
        ; return ([identif]:p_list:[])
        }

literal_tail :: Parser [[[String]]]
literal_tail = do{
            ; comma
            ; lit_list <- literal_list
            ; return lit_list
            }
        <|>
              do{
            ; whiteSpace
            ; return [[[]]]
            }
----------------------------------------------------------------------------
----------------------------------------------------------------------------
---------------------------Estructura de Marco------------------------------
----------------------------------------------------------------------------
----------------------------------------------------------------------------

-- Filtra las relaciones que son de tipo outputtuples
-- Entrada: Lineas del fichero correspondientes a las relaciones
-- Salida: Lista con las relaciones de tipo outputtuples
vOutputTuples :: [[Char]] -> [[Char]]
vOutputTuples (x:[])
    | isOutputTuple (relationsOutput x) = head (relationsOutput x)
    | otherwise = [[]]

vOutputTuples (x:xs)
    | isOutputTuple (relationsOutput x) = (head(head (relationsOutput x))):(vOutputTuples xs)
    | otherwise = vOutputTuples xs 


-- Devuelve true si es de tipo outputtuples
isOutputTuple :: [[[Char]]] -> Bool
isOutputTuple x
    | ((x!!2)!!0) == "outputtuples" = True
    | otherwise = False

-- Devuelve las lineas de las relaciones que se parsean
relationsOutput :: String ->  [[String]]
relationsOutput input = withoutRight (parse relation "" input)

-- Quita "Right" del resultado devuelto por el parser
withoutRight :: Either t t1 -> t1
withoutRight (Right x) = x

-----------------------------------------------------------------------------------------------

-- Comprueba si la lista que se le pasa contiene en el primer elemento de la sublista más interna coincide con rel
theSame :: String -> [[[[String]]]] -> Bool
theSame rel lin = rel == head(head(head(head lin)))

-- Devuelve unicamente parseadas las lineas que contienen el elemento buscado
filterClauses :: [String] -> String -> [[[[[String]]]]]
filterClauses (x:[]) rel
    | theSame rel (rulesOutput x) = [rulesOutput x]
    | otherwise = []

filterClauses (x:xs) rel
    | theSame rel (rulesOutput x) = ((rulesOutput x):(filterClauses xs rel))
    | otherwise = filterClauses xs rel

-- Ejecuta el parseados devolviendo el resultado y no mostrándolo por pantalla
rulesOutput :: String ->  [[[[String]]]]
rulesOutput input = withoutRight (parse clause "" input)

---------------------------------------------------------------------------------------
-- Módulos de salida

printaPgm l1 l2 = do
    putStrLn "aPgm = P["
    printTuples l1 l2
    putStrLn "        ]"
    putStrLn "        []"

-- Se le pasa la lista de relaciones y la lista entera de reglas y para cada relación imprime de la forma
-- correspondiente la lista de reglas asociadas
-- la primera lista es la de las relaciones y la segunda la de las reglas.
printTuples :: [[Char]] -> [[[[[[[Char]]]]]]] -> IO ()
printTuples (x:[]) (y:ys) = do
    putStr "        "
    putStrLn ("(\""++x++"\",[")
    printLastClause y

printTuples (x:xs) (y:ys) = do
    putStr "        "
    putStrLn ("(\""++x++"\",[")
    printClauses y
    printTuples xs ys

--Dada una lista de reglas las imprime con la forma que ha de tener en el fichero Datalog.hs

printClauses :: [[[[[[Char]]]]]] -> IO ()
printClauses (z:[]) = do
    putStr ("                Clause (\""++(head(head(head(head z))))++"\",[")
    printList (head(tail(head(head z)))) -- Imprime la cabeza
    putStr " ["
    printTailLastClause (head (tail z))
    putStr "        ])"
    putStrLn ","
    
printClauses (z:zs) = do
    putStr ("                Clause (\""++(head(head(head(head z))))++"\",[")
    printList (head(tail(head(head z)))) -- Imprime la cabeza
    putStr " ["
    printTail (head (tail z))
    printClauses zs

-- Igual que el anterior a diferencia que no imprime la coma en la ultima tupla del programa

printLastClause :: [[[[[[Char]]]]]] -> IO ()
printLastClause (z:[]) = do
    putStr ("                Clause (\""++(head(head(head(head z))))++"\",[")
    printList (head(tail(head(head z)))) -- Imprime la cabeza
    putStr " ["
    printTailLastClause (head (tail z))
    putStrLn "        ])"
    
printLastClause (z:zs) = do
    putStr ("                Clause (\""++(head(head(head(head z))))++"\",[")
    printList (head(tail(head(head z)))) -- Imprime la cabeza
    putStr " ["
    printTail (head (tail z))
    printLastClause zs

-- Dada una lista ["hola", "que", "tal"] la imprime de la forma ' "hola","que","tal"]) '

printList :: [String] -> IO ()
printList (k:[]) = putStr ("\""++k++"\"])")
printList (k:ks) = do
    putStr ("\""++k++"\",")
    printList ks

-- Imprime la cabeza, esto es toda la lista que forma el segundo miembro de "Clause"

printTail (x:[]) = do
    putStr ("(\""++(head(head x))++"\",[")
    printList (head(tail x))
    putStrLn "],"
    
printTail (x:xs) = do
    putStr ("(\""++(head(head x))++"\",[")
    printList (head(tail x))
    putStr ","
    printTail xs

-- Se diferencia del anterior únicamente porque no imprime la coma final.
printTailLastClause (x:[]) = do
    putStr ("(\""++(head(head x))++"\",[")
    printList (head(tail x))
    putStrLn "]"
    
printTailLastClause (x:xs) = do
    putStr ("(\""++(head(head x))++"\",[")
    printList (head(tail x))
    putStr ","
    printTailLastClause xs

----------------------------------------------------------------------------
----------------------------------------------------------------------------
----------------------------------MAIN--------------------------------------
----------------------------------------------------------------------------
----------------------------------------------------------------------------



main = do
-- Cabeceras del fichero generado
    inpt <- getContents
    let div_input = splitUpInput (lines inpt) 1
    putStrLn (unlines (last div_input))
    --domains (head div_input)
    --relations (head (tail div_input))
    --rules (head (tail (tail div_input)))
    
    




