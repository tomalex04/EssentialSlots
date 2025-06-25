<?php
class SMTP {
    private $config;
    private $socket;
    private $debug = false;

    public function __construct($config) {
        $this->config = $config;
    }

    public function send($to, $subject, $message, $headers) {
        try {
            $this->connect();
            $this->authenticate();
            
            // Send email
            $this->sendCommand("MAIL FROM: <{$this->config['smtp_username']}>");
            $this->sendCommand("RCPT TO: <$to>");
            $this->sendCommand("DATA");
            
            // Construct email
            $email = "Subject: $subject\r\n";
            $email .= $headers;
            $email .= "\r\n" . $message . "\r\n.";
            
            $this->sendCommand($email);
            $this->sendCommand("QUIT");
            
            fclose($this->socket);
            return true;
        } catch (Exception $e) {
            if ($this->socket) {
                fclose($this->socket);
            }
            throw $e;
        }
    }

    private function connect() {
        $host = $this->config['smtp_host'];
        $port = $this->config['smtp_port'];
        $secure = $this->config['smtp_secure'];
        
        $this->socket = fsockopen(
            ($secure == 'ssl' ? 'ssl://' : '') . $host,
            $port,
            $errno,
            $errstr,
            30
        );

        if (!$this->socket) {
            throw new Exception("Could not connect to SMTP server: $errstr ($errno)");
        }

        $this->readResponse();
        $this->sendCommand("EHLO " . $_SERVER['SERVER_NAME']);

        if ($secure == 'tls') {
            $this->sendCommand("STARTTLS");
            stream_socket_enable_crypto($this->socket, true, STREAM_CRYPTO_METHOD_TLS_CLIENT);
            $this->sendCommand("EHLO " . $_SERVER['SERVER_NAME']);
        }
    }

    private function authenticate() {
        $username = $this->config['smtp_username'];
        $password = $this->config['smtp_password'];

        $this->sendCommand("AUTH LOGIN");
        $this->sendCommand(base64_encode($username));
        $this->sendCommand(base64_encode($password));
    }

    private function sendCommand($command) {
        fwrite($this->socket, $command . "\r\n");
        return $this->readResponse();
    }

    private function readResponse() {
        $response = '';
        while ($str = fgets($this->socket, 515)) {
            $response .= $str;
            if (substr($str, 3, 1) == ' ') break;
        }
        if ($this->debug) {
            echo $response . "\n";
        }
        if (substr($response, 0, 3) >= 400) {
            throw new Exception("SMTP Error: " . $response);
        }
        return $response;
    }
}
?>
