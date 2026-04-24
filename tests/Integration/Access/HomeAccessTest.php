<?php

namespace Tests\Integration\Access;

use GuzzleHttp\Client;
use PHPUnit\Framework\TestCase;

class HomeAccessTest extends TestCase
{
    private Client $client;

    public function setUp(): void
    {
        parent::setUp();
        $this->client = new Client([
            'allow_redirects' => false,
            'base_uri' => 'http://web:8080'
        ]);
    }

    public function test_should_access_home_route(): void
    {
        $response = $this->client->get('/');

        $this->assertEquals(200, $response->getStatusCode());
        $this->assertStringContainsString('Home Page', (string) $response->getBody());
    }
}
